import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/companion/companion_actions.dart';
import 'package:ixland_mobile/companion/companion_character.dart';
import 'package:ixland_mobile/companion/companion_animator.dart';
import 'package:ixland_mobile/companion/companion_movement.dart';
import 'package:ixland_mobile/companion/companion_overlay.dart';
import 'package:ixland_mobile/companion/companion_overlay_app.dart';
import 'package:ixland_mobile/companion/companion_state.dart';
import 'package:ixland_mobile/companion/companion_wander_test.dart';
import 'package:ixland_mobile/companion/companion_window.dart';
import 'package:ixland_mobile/companion/styles/classic_style.dart';
import 'package:ixland_mobile/companion/styles/companion_look.dart';
import 'package:ixland_mobile/companion/styles/companion_style.dart';
import 'package:ixland_mobile/companion/styles/dress_up/dress_up_parts.dart';
import 'package:ixland_mobile/companion/styles/dress_up/dress_up_style.dart';
import 'package:ixland_mobile/devices/connected_devices_screen.dart';
import 'package:ixland_mobile/settings/patient_settings.dart';
import 'package:ixland_mobile/settings/settings_screen.dart';

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

  group('CompanionWanderTest', () {
    testWidgets('brings the companion back, then moves it on a timer', (
      tester,
    ) async {
      final companion = _FakeCompanionOverlay(granted: true);
      final wander = CompanionWanderTest(
        companion: companion,
        minDelay: const Duration(seconds: 5),
        maxDelay: const Duration(seconds: 5),
      )..start();

      await tester.pump(const Duration(seconds: 1));
      expect(companion.calls, ['hasPermission', 'isShowing', 'show']);

      companion.calls.clear();
      await tester.pump(const Duration(seconds: 5));
      expect(companion.calls, ['hasPermission', 'isShowing', 'moveTo']);

      // A dismissed companion is brought back instead of moved.
      companion.showing = false;
      companion.calls.clear();
      await tester.pump(const Duration(seconds: 5));
      expect(companion.calls, ['hasPermission', 'isShowing', 'show']);

      wander.stop();
      companion.calls.clear();
      await tester.pump(const Duration(seconds: 10));
      expect(companion.calls, isEmpty);
    });

    testWidgets('does nothing without overlay access', (tester) async {
      final companion = _FakeCompanionOverlay(granted: false);
      final wander = CompanionWanderTest(companion: companion)..start();
      await tester.pump(const Duration(seconds: 10));
      expect(companion.calls.toSet(), {'hasPermission'});
      wander.stop();
    });

    test(
      'picks delays uniformly from 4 to 8 seconds and points from 0 to 1',
      () {
        final wander = CompanionWanderTest(
          companion: _FakeCompanionOverlay(granted: true),
          random: math.Random(1),
        );
        final delays = List.generate(2000, (_) => wander.nextDelay());
        expect(
          delays.every(
            (d) =>
                d >= const Duration(seconds: 4) &&
                d <= const Duration(seconds: 8),
          ),
          isTrue,
        );
        // Roughly a quarter of the samples falls in each second.
        final firstSecond = delays
            .where((d) => d < const Duration(seconds: 5))
            .length;
        expect(firstSecond, inInclusiveRange(400, 600));

        final points = List.generate(500, (_) => wander.nextPoint());
        expect(
          points.every((p) => p.dx >= 0 && p.dx <= 1 && p.dy >= 0 && p.dy <= 1),
          isTrue,
        );
      },
    );

    testWidgets('runs only while the app is in the background', (tester) async {
      final companion = _FakeCompanionOverlay(granted: true, showing: true);
      await tester.pumpWidget(_devicesScreen(companion));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump(const Duration(seconds: 10));
      expect(companion.calls, contains('moveTo'));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      companion.calls.clear();
      await tester.pump(const Duration(seconds: 20));
      expect(companion.calls, isEmpty);
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

    testWidgets('opens from Connected devices with Classic selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        _devicesScreen(_FakeCompanionOverlay(granted: true)),
      );
      await tester.tap(find.byTooltip('Settings'));
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(find.text('Companion style'), findsOneWidget);
      expect(find.text('Classic'), findsOneWidget);
      expect(selected(tester, 'Classic'), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('saves the chosen style', (tester) async {
      final companion = _FakeCompanionOverlay(granted: true);
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            companion: companion,
            patientSettings: PatientSettings(),
            styles: const [ClassicCompanionStyle(), _DotStyle()],
          ),
        ),
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(selected(tester, 'Classic'), isTrue);

      await tester.tap(find.text('Dot'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(companion.calls, ['setLook:dot']);
      expect(companion.savedLook.styleId, 'dot');
      expect(selected(tester, 'Dot'), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('customizes Dress-up with a base, hat, and top', (
      tester,
    ) async {
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
      // Classic has nothing to customize.
      expect(find.text('Hat'), findsNothing);

      await tester.tap(find.text('Dress-up'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(companion.savedLook.styleId, 'dress_up');
      for (final label in [
        'Base',
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
      expect(companion.savedLook.choices['dress_up'], {
        'base': 'triangle',
        'hat': 'top_hat',
      });
      expect(
        companion.savedLook.resolve(),
        const DressUpCompanionStyle(base: TriangleBase(), hat: TopHat()),
      );

      // Switching style keeps the Dress-up choices for later.
      await tester.dragUntilVisible(
        find.text('Classic'),
        find.byType(ListView).first,
        const Offset(0, 200),
      );
      await tester.ensureVisible(find.text('Classic'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Classic'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('Hat'), findsNothing);
      expect(companion.savedLook.styleId, 'classic');
      expect(companion.savedLook.choices['dress_up']?['hat'], 'top_hat');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('keeps the old style when saving fails', (tester) async {
      final companion = _FakeCompanionOverlay(granted: true)..failSaving = true;
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            companion: companion,
            patientSettings: PatientSettings(),
            styles: const [ClassicCompanionStyle(), _DotStyle()],
          ),
        ),
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.text('Dot'));
      await pumpFor(tester, const Duration(milliseconds: 100));

      expect(selected(tester, 'Classic'), isTrue);
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
    final companion = find.byType(CompanionOverlayApp);

    setUp(() => native = _FakeNativeWindow()..install());
    tearDown(() => native.uninstall());

    Future<void> pumpFor(WidgetTester tester, Duration duration) async {
      const frame = Duration(milliseconds: 16);
      for (var t = Duration.zero; t < duration; t += frame) {
        await tester.pump(frame);
      }
    }

    Future<void> enter(WidgetTester tester) async {
      await tester.pumpWidget(
        const SizedBox(width: 192, height: 192, child: CompanionOverlayApp()),
      );
      // The 200 px walk in takes about 1.1 seconds.
      await pumpFor(tester, const Duration(seconds: 2));
      // Rest position is the right screen edge minus the window and margin.
      expect(native.x, 880);
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
    }

    testWidgets('tap bounces and says hello', (tester) async {
      await enter(tester);
      await tester.tap(companion);
      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(native.calls('showAlert').single.arguments, {
        'title': 'IXLand',
        'message': 'Hello world',
      });
      expect(native.x, 880);
      await finish(tester);
    });

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
      expect(native.calls('showAlert'), isEmpty);
      await finish(tester);
    });

    testWidgets('swipe up backflips with room above, then shrinks back', (
      tester,
    ) async {
      await enter(tester);
      await tester.fling(companion, const Offset(0, -60), 1000);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(native.calls('resize').map((c) => c.arguments), [
        {'width': 192.0, 'height': 320.0},
        {'width': 192.0, 'height': 192.0},
      ]);
      expect(native.calls('close'), isEmpty);
      await finish(tester);
    });

    testWidgets('swipe down is sad for two seconds and blocks inputs', (
      tester,
    ) async {
      await enter(tester);
      await tester.fling(companion, const Offset(0, 60), 1000);
      await pumpFor(tester, const Duration(seconds: 1));

      await tester.tap(companion);
      await tester.fling(companion, const Offset(-60, 0), 1000);
      await pumpFor(tester, const Duration(milliseconds: 200));
      expect(native.calls('showAlert'), isEmpty);
      expect(native.calls('close'), isEmpty);

      await pumpFor(tester, const Duration(seconds: 2));
      await tester.tap(companion);
      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(native.calls('showAlert'), hasLength(1));
      await finish(tester);
    });

    testWidgets('hold inflates with a sound until released', (tester) async {
      await enter(tester);
      final gesture = await tester.startGesture(tester.getCenter(companion));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(native.calls('playInflateSound').single.arguments, {
        'durationMs': 2000,
      });
      expect(native.calls('resize').single.arguments, {
        'width': 272.0,
        'height': 272.0,
      });

      // Inputs are still ignored while it shrinks back.
      await gesture.up();
      await tester.fling(companion, const Offset(-60, 0), 1000);
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(native.calls('stopSound'), isNotEmpty);
      expect(native.calls('resize').last.arguments, {
        'width': 192.0,
        'height': 192.0,
      });
      expect(native.calls('close'), isEmpty);
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
      const styles = [ClassicCompanionStyle(), _DotStyle()];
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

      await native.sendLook(tester, const CompanionLook(styleId: 'classic'));
      expect(drawn().id, 'classic');

      // An unknown style falls back to the first one.
      await native.sendLook(tester, const CompanionLook(styleId: 'gone'));
      expect(drawn().id, 'classic');
      await finish(tester);
    });

    testWidgets('draws the saved Dress-up choices', (tester) async {
      native.look = const CompanionLook(
        styleId: 'dress_up',
        choices: {
          'dress_up': {'base': 'triangle', 'hat': 'cap', 'top': 'doctor_coat'},
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
        const DressUpCompanionStyle(
          base: TriangleBase(),
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
            case 'moveTo':
              x = (args['x'] as num).toDouble();
              y = (args['y'] as num).toDouble();
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

  final bool granted;
  bool showing;
  final calls = <String>[];
  final moves = <Offset>[];

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
  Future<void> show() async {
    calls.add('show');
    showing = true;
  }

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
    moves.add(uv);
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
