import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/wearables/samsung/samsung_wear_adapter.dart';
import 'package:ixland_mobile/wearables/wearable_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const adapter = SamsungWearAdapter();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('discovers the watch and emits the common heart-rate events', () async {
    messenger.setMockMethodCallHandler(const MethodChannel('ixland/wear'), (
      call,
    ) async {
      expect(call.method, 'findWatches');
      return [
        {'id': 'watch-node', 'name': 'Galaxy Watch4'},
      ];
    });
    messenger.setMockStreamHandler(
      const EventChannel('ixland/wear/heart_rate'),
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          expect(arguments, 'watch-node');
          events.success('connected');
          events.success(0);
          events.success(76);
        },
      ),
    );

    final device = await adapter.scan().single;
    expect(device.name, 'Galaxy Watch4');
    final events = await adapter.connect(device).take(2).toList();
    expect(events.first, isA<WearableConnected>());
    expect(
      events.last,
      isA<HeartRateSample>().having((sample) => sample.bpm, 'BPM', 76),
    );
  });
}
