import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/wearables/samsung/samsung_wear_adapter.dart';
import 'package:ixland_mobile/wearables/wearable_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const adapter = SamsungWearAdapter();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test(
    'discovers the watch and emits BPM and cumulative step events',
    () async {
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
            events.success({'steps': -1});
            events.success({'steps': 0});
            events.success({'steps': 320});
          },
        ),
      );

      final device = await adapter.scan().single;
      expect(device.name, 'Galaxy Watch4');
      final events = await adapter.connect(device).take(4).toList();
      expect(events.first, isA<WearableConnected>());
      expect(
        events[1],
        isA<HeartRateSample>().having((sample) => sample.bpm, 'BPM', 76),
      );
      expect(
        events.whereType<StepCountSample>().map((sample) => sample.count),
        [0, 320],
      );
    },
  );
}
