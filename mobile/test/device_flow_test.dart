import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/devices/connected_devices_screen.dart';
import 'package:ixland_mobile/devices/provider_catalog.dart';
import 'package:ixland_mobile/main.dart';
import 'package:ixland_mobile/wearables/metric_batch_buffer.dart';
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
    await tester.pumpWidget(const SizedBox.shrink());
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
    final interval = tester
        .widget<ConnectedDevicesScreen>(find.byType(ConnectedDevicesScreen))
        .batchInterval;
    const configuredSeconds = int.fromEnvironment(
      'BATCH_UPLOAD_INTERVAL_SECONDS',
    );
    expect(interval.inSeconds, configuredSeconds > 0 ? configuredSeconds : 60);
    final start = MetricBatchBuffer(
      interval: interval,
    ).windowStart(DateTime.now()).subtract(interval);
    adapter.events.add(const WearableConnected());
    adapter.events.add(
      HeartRateSample(
        bpm: 72,
        receivedAt: start.add(const Duration(milliseconds: 100)),
      ),
    );
    adapter.events.add(
      HeartRateSample(
        bpm: 73,
        receivedAt: start.add(const Duration(milliseconds: 200)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('73 bpm'), findsOneWidget);
    expect(find.text('Samples in batch: 2'), findsOneWidget);
    expect(find.text('Batch JSON (debug)'), findsNothing);

    await tester.pump(interval);
    await tester.pumpAndSettle();
    expect(find.text('Batch JSON (debug)'), findsOneWidget);
    final preview = tester.widget<SelectableText>(find.byType(SelectableText));
    final payload = jsonDecode(preview.data!) as Map<String, dynamic>;
    expect(payload['hr'], [72, 73]);
    expect(payload['batch_interval_in_seconds'], interval.inSeconds);
    expect(find.text('Samples in batch: 0'), findsOneWidget);

    await tester.tap(find.text('Disconnect'));
    expect(adapter.events.hasListener, isFalse);
    adapter.disconnected.complete();
    await tester.pumpAndSettle();
    expect(find.text('No connected devices'), findsOneWidget);
    expect(find.text('Batch JSON (debug)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
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
