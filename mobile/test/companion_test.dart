import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/assistant/assistant_engine.dart';
import 'package:ixland_mobile/companion/companion_actions.dart';
import 'package:ixland_mobile/companion/companion_character.dart';
import 'package:ixland_mobile/companion/companion_chat_panel.dart';
import 'package:ixland_mobile/companion/companion_animator.dart';
import 'package:ixland_mobile/companion/companion_monitoring.dart';
import 'package:ixland_mobile/companion/companion_movement.dart';
import 'package:ixland_mobile/companion/companion_overlay.dart';
import 'package:ixland_mobile/companion/companion_overlay_app.dart';
import 'package:ixland_mobile/companion/companion_state.dart';
import 'package:ixland_mobile/companion/companion_window.dart';
import 'package:ixland_mobile/companion/styles/bot/bot_outfit.dart';
import 'package:ixland_mobile/companion/styles/bot/bot_shapes.dart';
import 'package:ixland_mobile/companion/styles/bot/bot_style.dart';
import 'package:ixland_mobile/companion/styles/companion_look.dart';
import 'package:ixland_mobile/companion/styles/companion_style.dart';
import 'package:ixland_mobile/devices/connected_devices_screen.dart';
import 'package:ixland_mobile/settings/patient_settings.dart';
import 'package:ixland_mobile/settings/settings_screen.dart';
import 'package:ixland_mobile/sync/monitoring_state.dart';

void main() {
  group('classifySwipe', () {
    test('uses fling velocity first and picks the larger axis', () {
      Offset v(double x, double y) => Offset(x, y);
      expect(
        classifySwipe(distance: v(4, 0), velocity: v(-900, 100)),
        CompanionInput.swipeLeft,
      );
      expect(
        classifySwipe(distance: v(-4, 0), velocity: v(900, 0)),
        CompanionInput.swipeRight,
      );
      expect(
        classifySwipe(distance: Offset.zero, velocity: v(200, -900)),
        CompanionInput.swipeUp,
      );
      expect(
        classifySwipe(distance: Offset.zero, velocity: v(-100, 900)),
        CompanionInput.swipeDown,
      );
    });

    test('falls back to drag distance and ignores small drags', () {
      expect(
        classifySwipe(distance: const Offset(0, 40), velocity: Offset.zero),
        CompanionInput.swipeDown,
      );
      expect(
        classifySwipe(distance: const Offset(10, 5), velocity: Offset.zero),
        isNull,
      );
    });
  });

  group('CompanionActionController', () {
    testWidgets('runs one action at a time', (tester) async {
      final window = CompanionWindow(
        channel: const MethodChannel('test/companion/window'),
      );
      final animator = CompanionAnimator(vsync: const TestVSync());
      final movement = CompanionMovementController(
        window: window,
        layout: _layout(),
        vsync: const TestVSync(),
      );
      final running = Completer<void>();
      final ran = <CompanionInput>[];
      final controller = CompanionActionController(
        actions: {
          CompanionInput.tap: (context) async {
            ran.add(CompanionInput.tap);
            context.animator.state = CompanionState.reacting;
            await running.future;
          },
          CompanionInput.swipeUp: (_) async => ran.add(CompanionInput.swipeUp),
        },
        animator: animator,
        movement: movement,
        window: window,
      );

      expect(controller.handle(CompanionInput.tap), isTrue);
      expect(controller.isBusy, isTrue);
      expect(controller.handle(CompanionInput.swipeUp), isFalse);
      expect(controller.handle(CompanionInput.hold), isFalse);

      running.complete();
      await tester.pump();
      expect(controller.isBusy, isFalse);
      expect(animator.state, CompanionState.idle);
      expect(controller.handle(CompanionInput.swipeUp), isTrue);
      await tester.pump();
      expect(ran, [CompanionInput.tap, CompanionInput.swipeUp]);

      movement.dispose();
      animator.dispose();
    });
  });

  group('TEST button', () {
    testWidgets('shows the companion and minimizes the app', (tester) async {
      final companion = _FakeCompanionOverlay(granted: true);
      await tester.pumpWidget(_devicesScreen(companion));

      expect(find.text('Add device'), findsOneWidget);
      await tester.tap(find.text('TEST'));
      await tester.pump();

      expect(companion.calls, ['hasPermission', 'show', 'minimizeApp']);
    });

    testWidgets('asks for overlay access and explains a denial', (
      tester,
    ) async {
      final companion = _FakeCompanionOverlay(granted: false);
      await tester.pumpWidget(_devicesScreen(companion));

      await tester.tap(find.text('TEST'));
      await tester.pump();

      expect(companion.calls, ['hasPermission', 'requestPermission']);
      expect(
        find.text(
          'Allow IXLand to display over other apps to test the companion.',
        ),
        findsOneWidget,
      );
    });
  });

  group('monitoring alerts', () {
    const normal = MonitoringStatus.normal;
    const warning = MonitoringStatus.warning;
    const critical = MonitoringStatus.critical;
    const emergency = MonitoringStatus.emergency;
    const patientId = 'fixture-patient';
    const emergencyNotice =
        'Contact your medical team immediately. '
        'Your monitoring results indicate a risk of complications.';

    MonitoringSnapshot snapshot(MonitoringStatus a, MonitoringStatus b) => (
      patientId: patientId,
      states: [
        MonitoringState(id: 's-00000001', status: a),
        MonitoringState(id: 's-00000002', status: b),
      ],
    );

    Map<String, Object?> cached(CompanionMonitoring monitoring, int index) =>
        monitoring.debugStates[index];

    test('raises all flags and groups addressed states in one alert', () async {
      final companion = _FakeCompanionOverlay(granted: false);
      final monitoring = CompanionMonitoring(companion)..setPatient(patientId);
      addTearDown(monitoring.dispose);

      await monitoring.update(snapshot(normal, normal));
      expect(companion.calls, isEmpty);
      await monitoring.update(snapshot(warning, critical));
      expect(cached(monitoring, 0), containsPair('summon', true));
      expect(cached(monitoring, 0), containsPair('addressed', true));
      expect(cached(monitoring, 0), containsPair('resolved', true));
      expect(companion.alerts, isEmpty);

      companion.granted = true;
      await monitoring.retry();
      expect(companion.calls.where((call) => call == 'show'), hasLength(1));
      expect(companion.alerts, ['s-00000001: warning\ns-00000002: critical']);
      expect(companion.checkInPrompts, isEmpty);
      for (final state in monitoring.debugStates) {
        expect(state, containsPair('summon', false));
        expect(state, containsPair('addressed', false));
        expect(state, containsPair('resolved', true));
      }
    });

    test(
      'summons the companion and shows one urgent alert for emergency states',
      () async {
        final companion = _FakeCompanionOverlay(granted: false);
        final monitoring = CompanionMonitoring(companion)
          ..setPatient(patientId);
        addTearDown(monitoring.dispose);

        final emergencies = snapshot(emergency, emergency);
        await monitoring.update(emergencies);
        expect(companion.showing, isFalse);
        expect(companion.alerts, isEmpty);
        expect(cached(monitoring, 0), containsPair('addressed', true));
        expect(cached(monitoring, 1), containsPair('addressed', true));

        companion.granted = true;
        await monitoring.retry();
        await monitoring.update(emergencies);
        expect(companion.showing, isTrue);
        expect(companion.alerts, [emergencyNotice]);
        expect(cached(monitoring, 0), containsPair('addressed', false));
        expect(cached(monitoring, 1), containsPair('addressed', false));

        companion.showing = false;
        await monitoring.onDismissed();
        expect(companion.showing, isTrue);
        expect(companion.alerts, [emergencyNotice, emergencyNotice]);
      },
    );

    test(
      'emergency escalation interrupts check-ins and defers lower-priority states',
      () async {
        final companion = _FakeCompanionOverlay(granted: true, showing: true);
        final monitoring = CompanionMonitoring(companion)
          ..setPatient(patientId);
        addTearDown(monitoring.dispose);

        Future<void> update(MonitoringStatus first, MonitoringStatus second) =>
            monitoring.update((
              patientId: patientId,
              states: [
                MonitoringState(
                  id: 's-00000001',
                  status: first,
                  prompt: 'First check-in.',
                ),
                MonitoringState(
                  id: 's-00000002',
                  status: second,
                  prompt: 'Second check-in.',
                ),
              ],
            ));

        await update(critical, normal);
        expect(companion.checkInPrompts, hasLength(1));
        expect(cached(monitoring, 0), containsPair('resolved', true));

        await update(emergency, warning);
        expect(companion.calls, isNot(contains('show')));
        expect(companion.calls.last, 'clearCheckIn');
        expect(companion.alerts, [emergencyNotice]);
        expect(companion.checkInPrompts, hasLength(1));
        expect(cached(monitoring, 1), containsPair('addressed', true));

        await monitoring.retry();
        expect(companion.checkInPrompts, hasLength(1));
        expect(companion.alerts, [emergencyNotice]);

        await update(normal, warning);
        expect(companion.checkInPrompts, hasLength(2));
        expect(cached(monitoring, 1), containsPair('addressed', false));
      },
    );

    test(
      'a prompted summon starts a check-in directly and retries failed handoffs',
      () async {
        final companion = _FakeCompanionOverlay(granted: true);
        final monitoring = CompanionMonitoring(companion)
          ..setPatient(patientId);
        addTearDown(monitoring.dispose);

        const first = 'First fixture prompt.';
        const second = 'Second fixture prompt.';
        Future<void> update(MonitoringStatus status, {bool both = true}) =>
            monitoring.update((
              patientId: patientId,
              states: [
                MonitoringState(
                  id: 's-00000001',
                  status: status,
                  prompt: first,
                ),
                if (both)
                  const MonitoringState(
                    id: 's-00000002',
                    status: normal,
                    prompt: second,
                  ),
              ],
            ));

        companion.failCheckIn = true;
        await update(warning);
        expect(cached(monitoring, 0), containsPair('addressed', true));
        companion.failCheckIn = false;
        await monitoring.retry();
        await update(critical);
        await update(critical);
        expect(companion.checkInPrompts, [
          '$first\n\n$second',
          '$first\n\n$second',
        ]);
        expect(cached(monitoring, 0), isNot(contains('prompt')));
        expect(companion.alerts, isEmpty);

        await update(normal);
        await update(critical, both: false);
        expect(companion.checkInPrompts.last, first);
        expect(companion.checkInPrompts, hasLength(3));

        monitoring.setPatient('other-patient');
        await monitoring.retry();
        expect(companion.calls.last, 'clearCheckIn');
      },
    );

    test(
      're-addresses every resolved-flag state on a swipe, including recovered states',
      () async {
        final companion = _FakeCompanionOverlay(granted: true, showing: true);
        final monitoring = CompanionMonitoring(companion)
          ..setPatient(patientId);
        addTearDown(monitoring.dispose);

        await monitoring.update(snapshot(critical, warning));
        await monitoring.update((
          patientId: patientId,
          states: const [MonitoringState(id: 's-00000003', status: normal)],
        ));
        expect(companion.calls, isNot(contains('show')));
        await monitoring.update(snapshot(normal, normal));
        await monitoring.update(snapshot(normal, warning));
        expect(companion.alerts, hasLength(1));
        expect(cached(monitoring, 0), containsPair('status', 'normal'));
        expect(
          cached(monitoring, 0),
          containsPair('previous_status', 'critical'),
        );

        companion.showing = false;
        await monitoring.onDismissed();
        expect(companion.showing, isTrue);
        expect(
          companion.alerts.last,
          's-00000001: normal (previously critical)\ns-00000002: warning',
        );
        expect(cached(monitoring, 1), containsPair('addressed', false));

        await monitoring.update(snapshot(normal, normal));
        companion.showing = false;
        companion.granted = false;
        await monitoring.onDismissed();
        expect(companion.alerts, hasLength(2));
        expect(cached(monitoring, 0), containsPair('addressed', true));
        expect(cached(monitoring, 1), containsPair('addressed', true));
        expect(cached(monitoring, 2), containsPair('resolved', false));
        expect(cached(monitoring, 2), containsPair('addressed', false));

        companion.granted = true;
        await monitoring.retry();
        expect(companion.showing, isTrue);
        expect(
          companion.alerts.last,
          's-00000001: normal (previously critical)\n'
          's-00000002: normal (previously warning)',
        );
        expect(cached(monitoring, 0), containsPair('addressed', false));
        expect(cached(monitoring, 1), containsPair('addressed', false));
      },
    );

    test(
      'keeps an unshown alert pending and clears the cache on patient change',
      () async {
        final companion = _FakeCompanionOverlay(granted: true)
          ..failAlert = true;
        final monitoring = CompanionMonitoring(companion)
          ..setPatient(patientId);
        addTearDown(monitoring.dispose);

        await monitoring.update(snapshot(warning, normal));
        expect(cached(monitoring, 0), containsPair('summon', false));
        expect(cached(monitoring, 0), containsPair('addressed', true));
        companion.failAlert = false;
        await monitoring.retry();
        expect(companion.alerts, ['s-00000001: warning']);

        monitoring.setPatient('other-patient');
        await monitoring.update(snapshot(critical, critical));
        expect(monitoring.debugStates, isEmpty);
        expect(companion.alerts, hasLength(1));
      },
    );

    testWidgets('backgrounding does not summon on a timer', (tester) async {
      final companion = _FakeCompanionOverlay(granted: true);
      await tester.pumpWidget(_devicesScreen(companion));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump(const Duration(seconds: 10));
      expect(companion.calls, contains('isShowing'));
      expect(companion.calls, isNot(contains('show')));
      expect(companion.calls, isNot(contains('moveTo')));

      companion.calls.clear();
      companion.showing = true;
      await tester.pump(const Duration(seconds: 10));
      expect(companion.calls, contains('moveTo'));
      expect(companion.calls, isNot(contains('show')));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('settings', () {
    Future<void> pumpFor(WidgetTester tester, Duration duration) async {
      const frame = Duration(milliseconds: 16);
      for (var t = Duration.zero; t < duration; t += frame) {
        await tester.pump(frame);
      }
    }

    bool selected(WidgetTester tester, String name) =>
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue ==
        tester
            .widget<RadioListTile<String>>(
              find.widgetWithText(RadioListTile<String>, name),
            )
            .value;

    testWidgets('opens from Connected devices with Bot selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        _devicesScreen(_FakeCompanionOverlay(granted: true)),
      );
      await tester.tap(find.byTooltip('Settings'));
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(find.text('Companion style'), findsOneWidget);
      expect(find.text('Bot'), findsOneWidget);
      expect(selected(tester, 'Bot'), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('picks the Bot shape', (tester) async {
      final companion = _FakeCompanionOverlay(granted: true);
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            companion: companion,
            patientSettings: PatientSettings(),
          ),
        ),
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('Shape'), findsOneWidget);
      expect(find.text('Green circle'), findsOneWidget);

      await tester.tap(find.text('Orange triangle'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(companion.savedLook.choices['bot'], {'shape': 'triangle'});
      expect(
        companion.savedLook.resolve(),
        const BotCompanionStyle(shape: BotTriangle()),
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('saves the chosen style', (tester) async {
      final companion = _FakeCompanionOverlay(granted: true);
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            companion: companion,
            patientSettings: PatientSettings(),
            styles: const [BotCompanionStyle(), _DotStyle()],
          ),
        ),
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(selected(tester, 'Bot'), isTrue);

      await tester.tap(find.text('Dot'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(companion.calls, ['setLook:dot']);
      expect(companion.savedLook.styleId, 'dot');
      expect(selected(tester, 'Dot'), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('customizes Bot with a shape, hat, and top', (tester) async {
      final companion = _FakeCompanionOverlay(granted: true);
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            companion: companion,
            patientSettings: PatientSettings(),
          ),
        ),
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      for (final label in [
        'Shape',
        'Green circle',
        'Orange triangle',
        'Hat',
        'Cat ears',
        'Cap',
        'Top hat',
        'Top',
        'T-shirt',
        "Doctor's coat",
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      await tester.tap(find.text('Orange triangle'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.scrollUntilVisible(
        find.text('Top hat'),
        50,
        scrollable: find.byType(Scrollable).at(2),
      );
      await tester.tap(find.text('Top hat'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(companion.savedLook.choices['bot'], {
        'shape': 'triangle',
        'hat': 'top_hat',
      });
      expect(
        companion.savedLook.resolve(),
        const BotCompanionStyle(shape: BotTriangle(), hat: TopHat()),
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('keeps the old style when saving fails', (tester) async {
      final companion = _FakeCompanionOverlay(granted: true)..failSaving = true;
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            companion: companion,
            patientSettings: PatientSettings(),
            styles: const [BotCompanionStyle(), _DotStyle()],
          ),
        ),
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.text('Dot'));
      await pumpFor(tester, const Duration(milliseconds: 100));

      expect(selected(tester, 'Bot'), isTrue);
      expect(find.text('Could not save the companion style.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('pointForUv', () {
    test('maps 0 to 1 coordinates into the padded screen area', () {
      final movement = CompanionMovementController(
        window: CompanionWindow(
          channel: const MethodChannel('test/companion/window'),
        ),
        layout: const CompanionWindowLayout(
          x: 0,
          y: 0,
          width: 192,
          height: 192,
          screenLeft: 0,
          screenTop: 100,
          screenRight: 1440,
          screenBottom: 3000,
          density: 2,
        ),
        vsync: const TestVSync(),
      );
      // 16 dp of padding is 32 px at density 2.
      expect(movement.pointForUv(Offset.zero), const Offset(32, 132));
      expect(movement.pointForUv(const Offset(1, 1)), const Offset(1216, 2776));
      expect(
        movement.pointForUv(const Offset(0.5, 0.5)),
        const Offset(624, 1454),
      );
      expect(movement.pointForUv(const Offset(2, -1)), const Offset(1216, 132));

      final reserved = CompanionMovementController(
        window: CompanionWindow(
          channel: const MethodChannel('test/companion/window'),
        ),
        layout: const CompanionWindowLayout(
          x: 0,
          y: 0,
          width: 192,
          height: 192,
          screenLeft: 0,
          screenTop: 100,
          screenRight: 1440,
          screenBottom: 3000,
          density: 2,
        ),
        vsync: const TestVSync(),
        reserve: const EdgeInsets.only(left: 40, right: 40, top: 128),
      );
      // The reserve adds 80 px at the sides and 256 px at the top.
      expect(reserved.pointForUv(Offset.zero), const Offset(112, 388));
      expect(reserved.pointForUv(const Offset(1, 1)), const Offset(1136, 2776));
      reserved.dispose();
      movement.dispose();
    });
  });

  group('overlay test actions', () {
    late _FakeNativeWindow native;
    late _FakeAssistant assistant;
    final companion = find.byType(CompanionOverlayApp);

    setUp(() {
      native = _FakeNativeWindow()..install();
      assistant = _FakeAssistant();
    });
    tearDown(() => native.uninstall());

    Future<void> pumpFor(WidgetTester tester, Duration duration) async {
      const frame = Duration(milliseconds: 16);
      for (var t = Duration.zero; t < duration; t += frame) {
        await tester.pump(frame);
      }
    }

    Future<void> enter(WidgetTester tester) async {
      await tester.pumpWidget(
        SizedBox(
          width: 192,
          height: 192,
          child: CompanionOverlayApp(assistant: assistant),
        ),
      );
      // The 200 px walk in takes about 1.1 seconds.
      await pumpFor(tester, const Duration(seconds: 2));
      // Rest position is the right screen edge minus the window and margin.
      expect(native.x, 880);
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
    }

    testWidgets('tap opens the chat, replies stream, and closing restores', (
      tester,
    ) async {
      await enter(tester);
      await tester.tap(companion);
      // The window hurries to the top-right corner before the chat opens.
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(native.calls('expand'), isEmpty);
      await pumpFor(tester, const Duration(seconds: 1));
      expect((native.calls('expand').length, native.lastMoveY), (1, 8.0));
      expect(assistant.loads, 1);
      expect(find.text('IXLand companion'), findsOneWidget);
      expect(find.textContaining('Gemma 4 E2B on CPU'), findsOneWidget);
      // The head slides up past the window edge to leave room for the panel.
      // It started 8 px from the top of the expanded window.
      final head = find.byType(CompanionCharacter);
      expect(tester.getTopLeft(head).dy, lessThan(-60));
      expect(
        tester.getTopLeft(find.byType(CompanionChatPanel)).dy,
        lessThan(200 - 8),
      );

      // The main app can't move the companion while the chat is open.
      expect(await native.sendMove(tester, 0.1, 0.1), isFalse);

      await tester.enterText(find.byType(TextField), 'Hi there');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(assistant.sent, ['Hi there']);
      expect(find.text('Hi there'), findsOneWidget);
      expect(find.text('…'), findsOneWidget);
      assistant.reply
        ..add('Hello')
        ..add(', friend!');
      await tester.pump();
      expect(find.text('Hello, friend!'), findsOneWidget);
      await assistant.reply.close();
      await tester.pump();

      await tester.tap(find.byTooltip('Close chat'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(native.calls('collapse'), hasLength(1));
      expect(find.text('IXLand companion'), findsNothing);
      // Then it hurries back to where it was.
      await pumpFor(tester, const Duration(seconds: 1));
      expect((native.x, native.y, native.width), (880.0, 1000.0, 192.0));

      // Reopening keeps the conversation in memory without loading again.
      await tester.tap(companion);
      await pumpFor(tester, const Duration(milliseconds: 1300));
      expect(find.text('Hello, friend!'), findsOneWidget);
      expect(assistant.loads, 1);

      // Back closes the open chat.
      await native.pressBack(tester);
      await pumpFor(tester, const Duration(milliseconds: 1300));
      expect(native.calls('collapse'), hasLength(2));
      await finish(tester);
    });

    testWidgets('chat explains where to put a missing model', (tester) async {
      assistant.loadResult = const AssistantState(
        AssistantStatus.missing,
        modelPath: '/sdcard/models/gemma-4-E2B-it.litertlm',
      );
      await enter(tester);
      await tester.tap(companion);
      await pumpFor(tester, const Duration(milliseconds: 1300));
      expect(find.text('Model file not found'), findsOneWidget);
      expect(
        find.textContaining('/sdcard/models/gemma-4-E2B-it.litertlm'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Hello?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(assistant.sent, isEmpty);
      await tester.tap(find.byTooltip('Close chat'));
      await pumpFor(tester, const Duration(milliseconds: 1300));
      await finish(tester);
    });

    testWidgets(
      'a summon opens the check-in and tapping resumes it until the patient changes',
      (tester) async {
        const prompt = 'First fixture prompt.\n\nSecond fixture prompt.';
        await enter(tester);
        await native.sendWindowEvent(
          tester,
          const MethodCall('startCheckIn', {'prompt': prompt}),
        );
        await pumpFor(tester, const Duration(milliseconds: 1300));
        expect(assistant.checkInPrompts, [prompt]);
        expect(assistant.sent, [contains('Begin the monitoring check-in')]);
        assistant.reply.add('How does your heart feel right now?');
        await tester.pump();
        expect(
          find.text('How does your heart feel right now?'),
          findsOneWidget,
        );

        await tester.tap(find.byTooltip('Close chat'));
        await pumpFor(tester, const Duration(milliseconds: 1300));
        expect(native.calls('collapse'), hasLength(1));
        await tester.tap(companion);
        await pumpFor(tester, const Duration(milliseconds: 1300));
        expect(assistant.checkInPrompts, [prompt]);
        expect(assistant.sent, hasLength(1));
        expect(
          find.text('How does your heart feel right now?'),
          findsOneWidget,
        );

        await native.sendWindowEvent(
          tester,
          const MethodCall('startCheckIn', {'prompt': prompt}),
        );
        await pumpFor(tester, const Duration(milliseconds: 1300));
        expect(native.calls('collapse'), hasLength(1));
        expect(assistant.sent, hasLength(1));

        await native.sendWindowEvent(tester, const MethodCall('clearCheckIn'));
        await pumpFor(tester, const Duration(milliseconds: 1300));
        expect(native.calls('collapse'), hasLength(2));
        await tester.tap(companion);
        await pumpFor(tester, const Duration(milliseconds: 1300));
        expect(assistant.checkInPrompts, [prompt, null]);
        expect(find.text('How does your heart feel right now?'), findsNothing);
        expect(assistant.sent, hasLength(1));
        await finish(tester);
      },
    );

    testWidgets(
      'a tap starts a queued check-in closed before its first question',
      (tester) async {
        const prompt = 'Fixture check-in prompt.';
        native.queuedCheckIn = prompt;
        await tester.pumpWidget(
          SizedBox(
            width: 192,
            height: 192,
            child: CompanionOverlayApp(assistant: assistant),
          ),
        );
        final panel = find.byType(CompanionChatPanel);
        for (var frame = 0; frame < 190 && panel.evaluate().isEmpty; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(native.calls('readyForCheckIns'), hasLength(1));
        expect(panel, findsOneWidget);
        expect(assistant.sent, isEmpty);

        await native.pressBack(tester);
        await pumpFor(tester, const Duration(milliseconds: 1300));
        expect(assistant.sent, isEmpty);
        await tester.tap(companion);
        await pumpFor(tester, const Duration(milliseconds: 1300));
        expect(assistant.checkInPrompts, [prompt]);
        expect(assistant.sent, [contains('Begin the monitoring check-in')]);
        await finish(tester);
      },
    );

    testWidgets('swipes left and right walk off and close', (tester) async {
      await enter(tester);
      await tester.fling(companion, const Offset(-60, 0), 1000);
      await pumpFor(tester, const Duration(seconds: 2));
      expect(native.x, -192);
      expect(native.log.last.method, 'close');
      await finish(tester);

      native.reset();
      await enter(tester);
      await tester.fling(companion, const Offset(60, 0), 1000);
      await pumpFor(tester, const Duration(seconds: 2));
      expect(native.x, 1080);
      expect(native.log.last.method, 'close');

      // Inputs after closing are ignored.
      await tester.tap(companion);
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(native.calls('expand'), isEmpty);
      await finish(tester);
    });

    /// Checks that a reaction started by [start] ignores a tap meanwhile
    /// and lets a tap open the chat after [length].
    Future<void> blocksInputsFor(
      WidgetTester tester,
      Duration length,
      Future<void> Function() start,
    ) async {
      await enter(tester);
      await start();
      await pumpFor(tester, length - const Duration(milliseconds: 400));
      await tester.tap(companion);
      await tester.fling(companion, const Offset(-60, 0), 1000);
      await pumpFor(tester, const Duration(milliseconds: 200));
      expect(native.calls('expand'), isEmpty);
      expect(native.calls('close'), isEmpty);
      // Emotions play inside the normal window.
      expect(native.calls('resize'), isEmpty);
      expect(native.calls('playInflateSound'), isEmpty);

      await pumpFor(tester, const Duration(milliseconds: 400));
      await tester.tap(companion);
      await pumpFor(tester, const Duration(milliseconds: 1300));
      expect(native.calls('expand'), hasLength(1));
      await native.pressBack(tester);
      await pumpFor(tester, const Duration(milliseconds: 1300));
      await finish(tester);
    }

    testWidgets('swipe up is scared and blocks inputs meanwhile', (
      tester,
    ) async {
      await blocksInputsFor(
        tester,
        CompanionAnimator.emotionDuration(CompanionEmotion.scared),
        () => tester.fling(companion, const Offset(0, -60), 1000),
      );
    });

    testWidgets('swipe down laughs and blocks inputs meanwhile', (
      tester,
    ) async {
      await blocksInputsFor(
        tester,
        CompanionAnimator.emotionDuration(CompanionEmotion.laughing),
        () => tester.fling(companion, const Offset(0, 60), 1000),
      );
    });

    testWidgets('hold is sad until released', (tester) async {
      await enter(tester);
      final gesture = await tester.startGesture(tester.getCenter(companion));
      // Still sad while held, however long that is.
      await pumpFor(tester, const Duration(seconds: 3));
      await tester.fling(companion, const Offset(-60, 0), 1000);
      await pumpFor(tester, const Duration(milliseconds: 200));
      expect(native.calls('close'), isEmpty);
      expect(native.calls('resize'), isEmpty);
      expect(native.calls('playInflateSound'), isEmpty);

      // Sadness fades out over a quarter second after release.
      await gesture.up();
      await pumpFor(tester, const Duration(milliseconds: 400));
      await tester.tap(companion);
      await pumpFor(tester, const Duration(milliseconds: 1300));
      expect(native.calls('expand'), hasLength(1));
      await native.pressBack(tester);
      await pumpFor(tester, const Duration(milliseconds: 1300));
      await finish(tester);
    });

    testWidgets('walks to a point the app sends unless busy', (tester) async {
      await enter(tester);

      expect(await native.sendMove(tester, 0.5, 0.25), isTrue);
      await pumpFor(tester, const Duration(seconds: 5));
      // Padding 16 plus growth room 16 at the sides and 128 at the top:
      // 32 + 0.5 * (1080 - 64 - 192) and 144 + 0.25 * (2000 - 160 - 192).
      expect(native.x, 444);
      expect(native.y, 556);

      // A running action declines the move.
      await tester.fling(companion, const Offset(0, 60), 1000);
      await pumpFor(tester, const Duration(milliseconds: 200));
      expect(await native.sendMove(tester, 0, 0), isFalse);
      await pumpFor(tester, const Duration(seconds: 3));
      expect(native.x, 444);
      await finish(tester);
    });

    testWidgets('draws the saved style and switches when it changes', (
      tester,
    ) async {
      native.look = const CompanionLook(styleId: 'dot');
      const styles = [BotCompanionStyle(), _DotStyle()];
      await tester.pumpWidget(
        const SizedBox(
          width: 192,
          height: 192,
          child: CompanionOverlayApp(styles: styles),
        ),
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      CompanionStyle drawn() => tester
          .widget<CompanionCharacter>(find.byType(CompanionCharacter))
          .style;
      expect(drawn().id, 'dot');

      await native.sendLook(tester, const CompanionLook(styleId: 'bot'));
      expect(drawn().id, 'bot');

      // An unknown style falls back to the first one.
      await native.sendLook(tester, const CompanionLook(styleId: 'gone'));
      expect(drawn().id, 'bot');
      await finish(tester);
    });

    testWidgets('draws the saved Bot choices', (tester) async {
      native.look = const CompanionLook(
        styleId: 'bot',
        choices: {
          'bot': {'shape': 'triangle', 'hat': 'cap', 'top': 'doctor_coat'},
        },
      );
      await tester.pumpWidget(
        const SizedBox(width: 192, height: 192, child: CompanionOverlayApp()),
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(
        tester
            .widget<CompanionCharacter>(find.byType(CompanionCharacter))
            .style,
        const BotCompanionStyle(
          shape: BotTriangle(),
          hat: Cap(),
          top: DoctorsCoat(),
        ),
      );
      await finish(tester);
    });

    testWidgets('a small drag keeps the companion on screen', (tester) async {
      await enter(tester);
      await tester.drag(companion, const Offset(20, 0), warnIfMissed: false);
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(native.calls('close'), isEmpty);
      expect(native.x, 880);
      await finish(tester);
    });
  });
}

CompanionWindowLayout _layout() => const CompanionWindowLayout(
  x: 1080,
  y: 1000,
  width: 96,
  height: 96,
  screenLeft: 0,
  screenTop: 0,
  screenRight: 1080,
  screenBottom: 2000,
  density: 1,
);

/// Stands in for `CompanionOverlayService` on the window channel.
class _FakeNativeWindow {
  static const _channel = MethodChannel('ixland/companion/window');
  final log = <MethodCall>[];
  double x = 1080;
  double y = 1000;
  double width = 192;
  double height = 192;
  CompanionLook look = const CompanionLook();
  String? queuedCheckIn;
  (double, double, double, double)? _collapsed;
  double? lastMoveY;

  Iterable<MethodCall> calls(String method) =>
      log.where((call) => call.method == method);

  void reset() {
    log.clear();
    x = 1080;
    y = 1000;
    width = 192;
    height = 192;
  }

  Map<String, Object> _layout() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'screenLeft': 0,
    'screenTop': 0,
    'screenRight': 1080,
    'screenBottom': 2000,
    'density': 1.0,
  };

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          log.add(call);
          final args = call.arguments is Map ? call.arguments as Map : {};
          switch (call.method) {
            case 'getLook':
              return look.toMap();
            case 'getLayout':
              return _layout();
            case 'readyForCheckIns':
              if (queuedCheckIn case final prompt?) {
                queuedCheckIn = null;
                await _sendWindowEvent(
                  MethodCall('startCheckIn', {'prompt': prompt}),
                );
              }
            case 'moveTo':
              x = (args['x'] as num).toDouble();
              y = (args['y'] as num).toDouble();
              lastMoveY = y;
            case 'expand':
              _collapsed = (x, y, width, height);
              x = 0;
              y = 0;
              width = 1080;
              height = 2000;
              return _layout();
            case 'collapse':
              final collapsed = _collapsed;
              _collapsed = null;
              if (collapsed != null) {
                final (cx, cy, cw, ch) = collapsed;
                x = cx;
                y = cy;
                width = cw;
                height = ch;
              }
              return _layout();
            case 'resize':
              final w = (args['width'] as num).toDouble();
              final h = (args['height'] as num).toDouble();
              x += (width - w) / 2;
              y += height - h;
              width = w;
              height = h;
              return _layout();
          }
          return null;
        });
  }

  /// Sends a move request from the service to the overlay, as the main app
  /// does through `CompanionOverlay.moveTo`.
  /// Tells the overlay that a new look was chosen, as the service does.
  Future<void> sendLook(WidgetTester tester, CompanionLook look) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          _channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('lookChanged', look.toMap()),
          ),
          (_) {},
        );
    await tester.pump();
  }

  Future<Object?> sendMove(WidgetTester tester, double u, double v) async {
    const codec = StandardMethodCodec();
    ByteData? reply;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          _channel.name,
          codec.encodeMethodCall(MethodCall('moveToUv', {'u': u, 'v': v})),
          (data) => reply = data,
        );
    await tester.pump();
    return codec.decodeEnvelope(reply!);
  }

  /// Presses Back, as the service reports it while the window is expanded.
  Future<void> pressBack(WidgetTester tester) =>
      sendWindowEvent(tester, const MethodCall('backPressed'));

  Future<void> sendWindowEvent(WidgetTester tester, MethodCall call) async {
    await _sendWindowEvent(call);
    await tester.pump();
  }

  Future<void> _sendWindowEvent(MethodCall call) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          _channel.name,
          const StandardMethodCodec().encodeMethodCall(call),
          (_) {},
        );
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}

/// A second style for testing style choice.
class _DotStyle extends CompanionStyle {
  const _DotStyle();

  @override
  String get id => 'dot';

  @override
  String get name => 'Dot';

  @override
  void paint(Canvas canvas, Size size, CompanionPose pose) {
    canvas.drawCircle(
      size.center(Offset.zero),
      20 * pose.inflate,
      Paint()..color = const Color(0xFF000000),
    );
  }
}

Widget _devicesScreen(CompanionOverlay companion) => MaterialApp(
  home: ConnectedDevicesScreen(
    adapters: const {},
    batchInterval: const Duration(minutes: 5),
    companion: companion,
    patientSettings: PatientSettings(),
  ),
);

class _FakeCompanionOverlay implements CompanionOverlay {
  _FakeCompanionOverlay({required this.granted, this.showing = false});

  bool granted;
  bool showing;
  bool failAlert = false;
  bool failCheckIn = false;
  final calls = <String>[];
  final alerts = <String>[];
  final checkInPrompts = <String>[];

  @override
  Future<bool> hasPermission() async {
    calls.add('hasPermission');
    return granted;
  }

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    return granted;
  }

  @override
  Future<bool> show() async {
    calls.add('show');
    return showing = true;
  }

  @override
  Stream<void> get dismissals => const Stream.empty();

  @override
  Future<bool> showAlert({
    required String title,
    required String message,
  }) async {
    if (failAlert) return false;
    alerts.add(message);
    return true;
  }

  @override
  Future<bool> startCheckIn(String prompt) async {
    if (failCheckIn) return false;
    checkInPrompts.add(prompt);
    return true;
  }

  @override
  Future<void> clearCheckIn() async => calls.add('clearCheckIn');

  @override
  Future<void> hide() async {
    calls.add('hide');
    showing = false;
  }

  @override
  Future<bool> isShowing() async {
    calls.add('isShowing');
    return showing;
  }

  @override
  Future<bool> moveTo(Offset uv) async {
    calls.add('moveTo');
    return true;
  }

  @override
  Future<void> minimizeApp() async => calls.add('minimizeApp');

  CompanionLook savedLook = const CompanionLook();
  bool failSaving = false;

  @override
  Future<CompanionLook> look() async => savedLook;

  @override
  Future<void> setLook(CompanionLook look) async {
    calls.add('setLook:${look.styleId}');
    if (failSaving) throw PlatformException(code: 'failed');
    savedLook = look;
  }
}

class _FakeAssistant implements AssistantEngine {
  AssistantState loadResult = const AssistantState(
    AssistantStatus.ready,
    backend: 'cpu',
    loadTime: Duration(milliseconds: 1500),
  );
  var loads = 0;
  final checkInPrompts = <String?>[];
  final sent = <String>[];
  final reply = StreamController<String>();

  @override
  Future<AssistantState> status() async => loadResult;

  @override
  Future<AssistantState> load({String? checkInPrompt}) async {
    loads++;
    checkInPrompts.add(checkInPrompt);
    return loadResult;
  }

  @override
  Stream<String> send(String text) {
    sent.add(text);
    return reply.stream;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> reset() async {}
}
