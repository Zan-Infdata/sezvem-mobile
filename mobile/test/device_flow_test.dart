import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/devices/provider_catalog.dart';
import 'package:ixland_mobile/main.dart';
import 'package:ixland_mobile/wearables/wearable_adapter.dart';
import 'package:ixland_mobile/wearables/whoop/whoop_ble_adapter.dart';

void main() {
  testWidgets('shows WHOOP setup steps before scanning', (tester) async {
    await tester.pumpWidget(IxlandApp(adapters: {'whoop': WhoopBleAdapter()}));
    expect(find.text('Sign in'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Connected devices'), findsOneWidget);
    expect(find.text('No connected devices'), findsOneWidget);

    await tester.tap(find.text('Add device'));
    await tester.pumpAndSettle();
    expect(find.text('WHOOP'), findsOneWidget);
    expect(find.text('Samsung Galaxy Watch'), findsOneWidget);

    await tester.tap(find.text('WHOOP'));
    await tester.pumpAndSettle();
    expect(find.text('Find WHOOP'), findsOneWidget);
    expect(
      find.text(
        'Confirm Android’s pairing prompt if it appears. Wear the strap to see your heart rate.',
      ),
      findsOneWidget,
    );
    expect(find.text('Scan for WHOOP'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Connected devices'), findsOneWidget);
  });

  testWidgets('connects the selected device and batches live readings', (
    tester,
  ) async {
    final adapter = _TestWearableAdapter();
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _ProviderTestBundle(),
        child: IxlandApp(adapters: {'whoop': adapter}),
      ),
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add device'));
    await tester.pumpAndSettle();

    expect(find.text('WHOOP'), findsOneWidget);
    expect(find.text('Samsung Galaxy Watch'), findsOneWidget);
    await tester.tap(find.text('WHOOP'));
    await tester.pumpAndSettle();
    expect(find.text('Find WHOOP'), findsOneWidget);
    expect(adapter.scanCalls, 0);
    expect(find.text('WHOOP test strap'), findsNothing);

    await tester.tap(find.text('Scan for WHOOP'));
    await tester.pumpAndSettle();
    expect(adapter.scanCalls, 1);
    await tester.tap(find.text('WHOOP test strap'));
    await tester.pumpAndSettle();
    expect(adapter.connectedDevice?.id, 'test-strap');
    adapter.events.add(const WearableConnected());
    adapter.events.add(
      HeartRateSample(
        bpm: 72,
        receivedAt: DateTime.utc(2026, 11, 21, 15, 0, 1),
      ),
    );
    adapter.events.add(
      HeartRateSample(
        bpm: 73,
        receivedAt: DateTime.utc(2026, 11, 21, 15, 0, 2),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('73 bpm'), findsOneWidget);
    expect(find.text('Samples in batch: 2'), findsOneWidget);

    await tester.tap(find.text('Disconnect'));
    expect(adapter.events.hasListener, isFalse);
    adapter.disconnected.complete();
    await tester.pumpAndSettle();
    expect(find.text('No connected devices'), findsOneWidget);
    unawaited(adapter.events.close());
  });
}

class _TestWearableAdapter implements WearableAdapter {
  final disconnected = Completer<void>();
  late final events = StreamController<WearableEvent>(
    onCancel: () => disconnected.future,
  );
  WearableDevice? connectedDevice;
  int scanCalls = 0;

  @override
  List<String> get setupSteps => const ['Enable the test strap.'];

  @override
  Stream<WearableDevice> scan() {
    scanCalls++;
    return Stream.value(
      const WearableDevice(id: 'test-strap', name: 'WHOOP test strap'),
    );
  }

  @override
  Stream<WearableEvent> connect(WearableDevice device) {
    connectedDevice = device;
    return events.stream;
  }
}

class _ProviderTestBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == ProviderCatalog.assetPath) {
      return '''
[
  {"id": "whoop", "name": "WHOOP"},
  {"id": "samsung", "name": "Samsung Galaxy Watch"}
]
''';
    }
    return rootBundle.loadString(key, cache: cache);
  }
}
