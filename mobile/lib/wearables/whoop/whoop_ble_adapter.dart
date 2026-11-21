import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../wearable_adapter.dart';
import 'whoop4_protocol.dart';

final _heartRateService = Uuid.parse('180d').expanded;
final _heartRateMeasurement = Uuid.parse('2a37').expanded;
final _whoop4Service = Uuid.parse('61080001-8d6d-82b8-614a-1c8cb0f8dcc6');
final _whoop4Command = Uuid.parse('61080002-8d6d-82b8-614a-1c8cb0f8dcc6');
final _whoop4Data = Uuid.parse('61080005-8d6d-82b8-614a-1c8cb0f8dcc6');
const _permissions = MethodChannel('ixland/bluetooth');

final class WhoopBleAdapter implements WearableAdapter {
  late final _ble = FlutterReactiveBle();

  @override
  List<String> get setupSteps => const [
    'Turn on Bluetooth and keep your WHOOP 4.0 near this phone.',
    'Slide the charged battery pack onto the strap to wake it. A flashing blue light means it is ready to pair.',
    'Tap Scan for WHOOP, allow Bluetooth access, and select your strap.',
    'Confirm Android’s pairing prompt if it appears. Wear the strap to see your heart rate.',
    'You can also connect to a strap with Heart Rate Broadcast already enabled.',
  ];

  @override
  Stream<WearableDevice> scan() async* {
    final granted = await _permissions.invokeMethod<bool>(
      'requestScanPermissions',
    );
    if (granted != true) {
      throw const WearableException(
        'Allow Bluetooth scanning in Android app settings and try again.',
      );
    }

    final status = await _ble.statusStream
        .timeout(const Duration(seconds: 5), onTimeout: (sink) => sink.close())
        .firstWhere(
          (status) =>
              status != BleStatus.unknown && status != BleStatus.unauthorized,
          orElse: () => _ble.status,
        );
    if (status != BleStatus.ready) {
      throw WearableException(switch (status) {
        BleStatus.poweredOff => 'Turn on Bluetooth and try again.',
        BleStatus.unsupported => 'Bluetooth LE requires a supported phone.',
        BleStatus.locationServicesDisabled =>
          'Turn on Location to scan on this version of Android.',
        _ => 'Bluetooth is unavailable. Check Android settings and try again.',
      });
    }

    yield* Stream<WearableDevice>.multi((results) {
      final scan = _ble
          .scanForDevices(withServices: [], scanMode: ScanMode.lowLatency)
          .listen(
            (device) {
              final name = device.name.trim();
              final whoop4 = device.serviceUuids.contains(_whoop4Service);
              final whoop = whoop4 || name.toLowerCase().contains('whoop');
              final unnamedHeartRate =
                  name.isEmpty &&
                  device.serviceUuids.any(
                    (uuid) => uuid.expanded == _heartRateService,
                  );
              if (whoop || unnamedHeartRate) {
                results.add(
                  WearableDevice(
                    id: device.id,
                    name: name.isNotEmpty
                        ? name
                        : whoop4
                        ? 'WHOOP 4.0'
                        : 'Unnamed heart-rate device',
                  ),
                );
              }
            },
            onError: (Object error, StackTrace stack) {
              results.addError(error, stack);
              results.close();
            },
            onDone: results.close,
          );
      final timer = Timer(const Duration(seconds: 12), results.close);
      results.onCancel = () {
        timer.cancel();
        return scan.cancel();
      };
    });
  }

  @override
  Stream<WearableEvent> connect(WearableDevice device) {
    StreamSubscription<ConnectionStateUpdate>? link;
    final measurements = <StreamSubscription<int>>[];
    Characteristic? liveControl;
    Timer? keepAlive;
    Timer? firstReadingTimeout;
    final commands = Whoop4Commands();
    var connected = false;
    var closing = false;
    late final StreamController<WearableEvent> events;

    void finish([WearableException? error]) {
      if (closing) return;
      closing = true;
      keepAlive?.cancel();
      firstReadingTimeout?.cancel();
      if (error != null) events.addError(error);
      unawaited(events.close());
    }

    Future<void> setLiveHeartRate(Characteristic command, bool enabled) =>
        command
            .write(commands.setLiveHeartRate(enabled: enabled))
            .timeout(const Duration(seconds: 5));

    void listenForHeartRates(List<Stream<int>> sources) {
      int? activeSource;
      var endedSources = 0;
      events.add(const WearableConnected());
      firstReadingTimeout = Timer(const Duration(seconds: 45), () {
        finish(
          const WearableException(
            'No heart rate received. Wear your WHOOP and reconnect, or try Heart Rate Broadcast.',
          ),
        );
      });
      for (final (index, readings) in sources.indexed) {
        void sourceEnded() {
          endedSources++;
          if (activeSource == index) activeSource = null;
          if (endedSources == sources.length) {
            finish(
              const WearableException(
                'Could not read heart rate. Wear your WHOOP and try reconnecting.',
              ),
            );
          }
        }

        measurements.add(
          readings.listen(
            (bpm) {
              if (closing) return;
              activeSource ??= index;
              if (activeSource == index) {
                firstReadingTimeout?.cancel();
                events.add(
                  HeartRateSample(bpm: bpm, receivedAt: DateTime.now().toUtc()),
                );
              }
            },
            onError: (Object _) => sourceEnded(),
            onDone: sourceEnded,
            cancelOnError: true,
          ),
        );
      }
    }

    Future<void> startSession() async {
      try {
        final services = await _ble
            .getDiscoveredServices(device.id)
            .timeout(const Duration(seconds: 12));
        if (closing) return;

        final command = _findCharacteristic(
          services,
          _whoop4Service,
          _whoop4Command,
        );
        final liveData = _findCharacteristic(
          services,
          _whoop4Service,
          _whoop4Data,
        );
        final broadcast = _findCharacteristic(
          services,
          _heartRateService,
          _heartRateMeasurement,
        );
        final broadcastReadings = broadcast
            ?.subscribe()
            .map(decodeHeartRate)
            .where((bpm) => bpm != null)
            .cast<int>();
        if (command != null &&
            command.isWritableWithResponse &&
            liveData != null) {
          try {
            // An acknowledged write to this protected characteristic initiates
            // the normal Android bonding flow when the device requests it.
            await command
                .write(commands.requestBattery())
                .timeout(const Duration(seconds: 35));
            if (closing) return;

            await setLiveHeartRate(command, true);
            if (closing) return;
            liveControl = command;
            final decoder = Whoop4HeartRateDecoder();
            listenForHeartRates([
              liveData.subscribe().expand(decoder.add),
              if (broadcastReadings != null) broadcastReadings,
            ]);
            keepAlive = Timer.periodic(const Duration(seconds: 30), (_) async {
              if (closing) return;
              try {
                await setLiveHeartRate(command, true);
              } catch (_) {
                keepAlive?.cancel();
              }
            });
            return;
          } catch (_) {
            if (closing) return;
            if (broadcastReadings == null) {
              finish(
                const WearableException(
                  'Could not start live heart rate. Wake the WHOOP 4.0, confirm pairing if prompted, and try again.',
                ),
              );
              return;
            }
          }
        }

        if (broadcastReadings == null) {
          finish(
            const WearableException(
              'No supported heart-rate service was found on this device.',
            ),
          );
          return;
        }
        listenForHeartRates([broadcastReadings]);
      } catch (_) {
        finish(
          const WearableException(
            'Could not set up heart rate. Check Bluetooth and try reconnecting.',
          ),
        );
      }
    }

    events = StreamController<WearableEvent>(
      onListen: () {
        link = _ble
            .connectToDevice(
              id: device.id,
              connectionTimeout: const Duration(seconds: 15),
            )
            .listen(
              (update) {
                if (closing) return;
                if (update.connectionState ==
                    DeviceConnectionState.disconnected) {
                  finish(
                    const WearableException('Bluetooth connection ended.'),
                  );
                }
                if (update.connectionState == DeviceConnectionState.connected &&
                    !connected) {
                  connected = true;
                  unawaited(startSession());
                }
              },
              onError: (Object _) => finish(
                const WearableException(
                  'Could not connect. Wake your WHOOP and try scanning again.',
                ),
              ),
              onDone: finish,
            );
      },
      onCancel: () async {
        final stoppedByUser = !closing;
        closing = true;
        keepAlive?.cancel();
        firstReadingTimeout?.cancel();
        try {
          final command = liveControl;
          if (stoppedByUser && command != null) {
            try {
              await setLiveHeartRate(command, false);
            } catch (_) {
              // Closing the link also ends its live stream.
            }
          }
          await Future.wait(measurements.map((reading) => reading.cancel()));
        } finally {
          await link?.cancel();
        }
      },
    );
    return events.stream;
  }
}

Characteristic? _findCharacteristic(
  List<Service> services,
  Uuid serviceId,
  Uuid characteristicId,
) {
  for (final service in services) {
    if (service.id.expanded != serviceId) continue;
    for (final characteristic in service.characteristics) {
      if (characteristic.id.expanded == characteristicId) return characteristic;
    }
  }
  return null;
}

int? decodeHeartRate(List<int> packet) {
  if (packet.length < 2) return null;
  final flags = packet[0];
  final hasContact = flags & 0x04 == 0 || flags & 0x02 != 0;
  final isUint16 = flags & 0x01 != 0;
  if (!hasContact || (isUint16 && packet.length < 3)) return null;
  final bpm = isUint16 ? packet[1] | (packet[2] << 8) : packet[1];
  return bpm > 0 ? bpm : null;
}
