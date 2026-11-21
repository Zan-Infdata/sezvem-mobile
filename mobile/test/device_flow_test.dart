import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/devices/connected_devices_screen.dart';
import 'package:ixland_mobile/devices/provider_catalog.dart';
import 'package:ixland_mobile/main.dart';
import 'package:ixland_mobile/settings/patient_settings.dart';
import 'package:ixland_mobile/sync/telemetry_api.dart';
import 'package:ixland_mobile/wearables/metric_batch_buffer.dart';
import 'package:ixland_mobile/wearables/wearable_adapter.dart';
import 'package:ixland_mobile/wearables/whoop/whoop_ble_adapter.dart';

void main() {
  testWidgets('shows WHOOP setup steps before scanning', (tester) async {
    await tester.pumpWidget(
      IxlandApp(
        adapters: {'whoop': WhoopBleAdapter()},
        patientSettings: PatientSettings(),
      ),
    );
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
    final api = _TestTelemetryApi();
    final patient = PatientSettings(
      defaultId: 'fixture-patient',
      createPatient: () async => 'p-abcdef01',
    );
    const settingsChannel = MethodChannel('ixland/patient_settings');
    const companionChannel = MethodChannel('ixland/companion');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(settingsChannel, (call) async => null);
    messenger.setMockMethodCallHandler(companionChannel, (call) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(settingsChannel, null);
      messenger.setMockMethodCallHandler(companionChannel, null);
    });
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _ProviderTestBundle(),
        child: IxlandApp(
          adapters: {'whoop': adapter},
          patientSettings: patient,
          telemetryApi: api,
        ),
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
    ).windowStart(DateTime.now()).subtract(interval * 3);

    Map<String, dynamic> previewPayload() {
      final preview = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      return jsonDecode(preview.data!) as Map<String, dynamic>;
    }

    Future<void> tickBatchTimer() async {
      await tester.pump(interval);
      await tester.pumpAndSettle();
    }

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

    await tickBatchTimer();
    expect(find.text('Batch JSON (debug)'), findsOneWidget);
    final payload = previewPayload();
    expect(api.posts, [payload]);
    expect(payload['patient_id'], 'fixture-patient');
    expect(payload['hr'], [72, 73]);
    expect(payload['extra'], {'batch_interval_in_seconds': interval.inSeconds});
    expect(find.text('Samples in batch: 0'), findsOneWidget);

    final jam = find.widgetWithText(CheckboxListTile, 'Debug jam');
    expect(tester.widget<CheckboxListTile>(jam).value, isFalse);
    await tester.tap(jam);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(jam).value, isTrue);

    adapter.events.add(
      HeartRateSample(bpm: 74, receivedAt: start.add(interval)),
    );
    await tickBatchTimer();
    final rejected = previewPayload();
    expect(rejected['hr'], [74]);
    expect(find.text('Samples in batch: 1'), findsOneWidget);

    adapter.events.add(
      HeartRateSample(bpm: 75, receivedAt: start.add(interval * 2)),
    );
    await tickBatchTimer();
    final extended = previewPayload();
    expect(extended['batch_number'], rejected['batch_number']);
    expect(extended['hr'], [74, 75]);
    expect(extended['extra'], {
      'batch_interval_in_seconds': interval.inSeconds * 2,
    });
    expect(find.text('Samples in batch: 2'), findsOneWidget);
    expect(api.posts, [payload]);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Create patient'));
    await tester.pump();
    expect(patient.patientId, 'p-abcdef01');
    expect(find.text('Patient created.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    adapter.events.add(
      HeartRateSample(bpm: 76, receivedAt: start.add(interval * 2)),
    );
    await tester.pump();
    await tester.tap(jam);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(jam).value, isFalse);
    await tickBatchTimer();
    final next = previewPayload();
    expect(api.posts, [payload, extended, next]);
    expect(next['patient_id'], 'p-abcdef01');
    expect(next['hr'], [76]);
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

class _TestTelemetryApi extends TelemetryApi {
  _TestTelemetryApi() : super(url: 'https://example.test/batches');

  final posts = <Map<String, Object?>>[];

  @override
  Future<TelemetryUploadResult> send(Map<String, Object?> payload) async {
    posts.add(payload);
    return (accepted: true, status: 'Uploaded (HTTP 201).');
  }
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
