import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/companion/companion_character.dart';
import 'package:ixland_mobile/companion/companion_overlay.dart';
import 'package:ixland_mobile/companion/companion_overlay_app.dart';
import 'package:ixland_mobile/devices/connected_devices_screen.dart';

void main() {
  group('classifySwipe', () {
    test('uses fling velocity first', () {
      expect(classifySwipe(distance: 4, velocity: -900), SwipeDirection.left);
      expect(classifySwipe(distance: -4, velocity: 900), SwipeDirection.right);
    });

    test('falls back to drag distance and ignores small drags', () {
      expect(classifySwipe(distance: 40, velocity: 0), SwipeDirection.right);
      expect(classifySwipe(distance: -40, velocity: 0), SwipeDirection.left);
      expect(classifySwipe(distance: 10, velocity: 100), isNull);
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

  group('overlay', () {
    const channel = MethodChannel('ixland/companion/window');
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'getLayout') {
              return {
                'x': 1080,
                'y': 1000,
                'width': 96,
                'height': 96,
                'screenLeft': 0,
                'screenTop': 0,
                'screenRight': 1080,
                'screenBottom': 2000,
                'density': 1.0,
              };
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    double lastX() =>
        (calls.lastWhere((c) => c.method == 'moveTo').arguments as Map)['x']
            .toDouble();

    Future<void> pumpFor(WidgetTester tester, Duration duration) async {
      const frame = Duration(milliseconds: 16);
      for (var t = Duration.zero; t < duration; t += frame) {
        await tester.pump(frame);
      }
    }

    testWidgets('walks in, says hello on tap, and leaves on a swipe', (
      tester,
    ) async {
      await tester.pumpWidget(
        const SizedBox(width: 96, height: 96, child: CompanionOverlayApp()),
      );
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.byType(CompanionCharacter), findsOneWidget);
      // Rest position is the right screen edge minus the window and margin.
      expect(lastX(), 976);

      await tester.tap(find.byType(CompanionOverlayApp));
      await pumpFor(tester, const Duration(milliseconds: 400));
      final alert = calls.singleWhere((c) => c.method == 'showAlert');
      expect(alert.arguments, {'title': 'IXLand', 'message': 'Hello world'});

      await tester.fling(
        find.byType(CompanionOverlayApp),
        const Offset(-60, 0),
        1000,
      );
      await pumpFor(tester, const Duration(seconds: 2));
      expect(lastX(), -96);
      expect(calls.last.method, 'close');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a small drag keeps the companion on screen', (tester) async {
      await tester.pumpWidget(
        const SizedBox(width: 96, height: 96, child: CompanionOverlayApp()),
      );
      await pumpFor(tester, const Duration(seconds: 1));

      await tester.drag(
        find.byType(CompanionOverlayApp),
        const Offset(20, 0),
        warnIfMissed: false,
      );
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(calls.where((c) => c.method == 'close'), isEmpty);
      expect(lastX(), 976);

      await tester.pumpWidget(const SizedBox());
    });
  });
}

Widget _devicesScreen(CompanionOverlay companion) => MaterialApp(
  home: ConnectedDevicesScreen(
    adapters: const {},
    batchInterval: const Duration(minutes: 5),
    companion: companion,
  ),
);

class _FakeCompanionOverlay implements CompanionOverlay {
  _FakeCompanionOverlay({required this.granted});

  final bool granted;
  final calls = <String>[];

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
  Future<void> show() async => calls.add('show');

  @override
  Future<void> hide() async => calls.add('hide');

  @override
  Future<void> minimizeApp() async => calls.add('minimizeApp');
}
