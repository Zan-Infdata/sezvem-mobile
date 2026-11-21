import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'companion/companion_overlay_app.dart';
import 'devices/connected_devices_screen.dart';
import 'settings/patient_settings.dart';
import 'sync/telemetry_api.dart';
import 'wearables/samsung/samsung_wear_adapter.dart';
import 'wearables/wearable_adapter.dart';
import 'wearables/whoop/whoop_ble_adapter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final patientSettings = PatientSettings(
    defaultId: const String.fromEnvironment('BATCH_PATIENT_ID'),
  );
  try {
    await patientSettings.load();
  } on PlatformException catch (error) {
    debugPrint('Could not load patient settings (${error.code}).');
  } on MissingPluginException {
    // Local patient settings are available in the Android phone app.
  }
  runApp(
    IxlandApp(
      adapters: {
        'whoop': WhoopBleAdapter(),
        'samsung': const SamsungWearAdapter(),
      },
      patientSettings: patientSettings,
      telemetryApi: TelemetryApi(
        url: const String.fromEnvironment(
          'BATCH_API_URL',
          defaultValue:
              'https://europe-west3-pati-api-8fac6.cloudfunctions.net/api/batches',
        ),
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
  const IxlandApp({
    super.key,
    required this.adapters,
    required this.patientSettings,
    this.telemetryApi,
  });

  final Map<String, WearableAdapter> adapters;
  final PatientSettings patientSettings;
  final TelemetryApi? telemetryApi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IXLand',
      home: LoginScreen(
        adapters: adapters,
        patientSettings: patientSettings,
        telemetryApi: telemetryApi,
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.adapters,
    required this.patientSettings,
    this.telemetryApi,
  });

  final Map<String, WearableAdapter> adapters;
  final PatientSettings patientSettings;
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
                  patientSettings: patientSettings,
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
