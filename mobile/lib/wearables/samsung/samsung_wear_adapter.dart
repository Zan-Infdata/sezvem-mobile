import 'package:flutter/services.dart';

import '../wearable_adapter.dart';

final class SamsungWearAdapter implements WearableAdapter {
  const SamsungWearAdapter();

  static const _commands = MethodChannel('ixland/wear');
  static const _heartRate = EventChannel('ixland/wear/heart_rate');

  @override
  List<String> get setupSteps => const [
    'Pair your Galaxy Watch with this phone in Galaxy Wearable.',
    'Install and open IXLand Watch on your watch.',
    'Tap Scan for Samsung Galaxy Watch here and select your watch.',
    'On the watch, tap Start and allow heart-rate access. Keep the watch app open to stream readings.',
  ];

  @override
  Stream<WearableDevice> scan() async* {
    final List<dynamic> watches;
    try {
      watches =
          await _commands.invokeListMethod<Map<dynamic, dynamic>>(
            'findWatches',
          ) ??
          [];
    } on PlatformException {
      throw const WearableException(
        'Could not find your watch. Check that it is paired with this phone.',
      );
    }
    for (final watch in watches) {
      if (watch case {'id': final String id, 'name': final String name}) {
        yield WearableDevice(id: id, name: name);
      }
    }
  }

  @override
  Stream<WearableEvent> connect(WearableDevice device) async* {
    try {
      await for (final event in _heartRate.receiveBroadcastStream(device.id)) {
        if (event == 'connected') {
          yield const WearableConnected();
        } else if (event is int && event > 0) {
          yield HeartRateSample(bpm: event, receivedAt: DateTime.now().toUtc());
        }
      }
    } on PlatformException {
      throw const WearableException(
        'Could not receive readings. Open IXLand Watch and reconnect.',
      );
    }
  }
}
