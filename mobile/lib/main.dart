import 'package:flutter/material.dart';

import 'devices/connected_devices_screen.dart';
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
    ),
  );
}

class IxlandApp extends StatelessWidget {
  const IxlandApp({super.key, required this.adapters});

  final Map<String, WearableAdapter> adapters;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IXLand',
      home: LoginScreen(adapters: adapters),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.adapters});

  final Map<String, WearableAdapter> adapters;

  @override
  Widget build(BuildContext context) {
    const minutes = int.fromEnvironment(
      'BATCH_UPLOAD_INTERVAL_MINUTES',
      defaultValue: 5,
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
                  batchInterval: const Duration(
                    minutes: minutes > 0 ? minutes : 5,
                  ),
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
