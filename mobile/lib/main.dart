import 'package:flutter/material.dart';

import 'companion/companion_overlay_app.dart';
import 'devices/connected_devices_screen.dart';
import 'sync/telemetry_api.dart';
import 'wearables/samsung/samsung_wear_adapter.dart';
import 'wearables/wearable_adapter.dart';
import 'wearables/whoop/whoop_ble_adapter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    IxlandApp(
      adapters: {
        'whoop': WhoopBleAdapter(),
        'samsung': const SamsungWearAdapter(),
      },
      telemetryApi: TelemetryApi(
        url: const String.fromEnvironment(
          'BATCH_API_URL',
          defaultValue:
              'https://europe-west3-pati-api-8fac6.cloudfunctions.net/api/batches',
        ),
        patientId: const String.fromEnvironment('BATCH_PATIENT_ID'),
      ),
    ),
  );
}

/// Entry point of the companion overlay engine started by
/// `CompanionOverlayService`. It must stay in this library so Android can find it.
@pragma('vm:entry-point')
void companionOverlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CompanionOverlayApp());
}

class IxlandApp extends StatelessWidget {
  const IxlandApp({super.key, required this.adapters, this.telemetryApi});

  final Map<String, WearableAdapter> adapters;
  final TelemetryApi? telemetryApi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IXLand',
      home: LoginScreen(adapters: adapters, telemetryApi: telemetryApi),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.adapters, this.telemetryApi});

  final Map<String, WearableAdapter> adapters;
  final TelemetryApi? telemetryApi;

  @override
  Widget build(BuildContext context) {
    const defaultSeconds = 60;
    const seconds = int.fromEnvironment(
      'BATCH_UPLOAD_INTERVAL_SECONDS',
      defaultValue: defaultSeconds,
    );
    const batchInterval = Duration(
      seconds: seconds > 0 ? seconds : defaultSeconds,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => ConnectedDevicesScreen(
                  adapters: adapters,
                  batchInterval: batchInterval,
                  telemetryApi: telemetryApi,
                ),
              ),
            );
          },
          child: const Text('Continue'),
        ),
      ),
    );
  }
}
