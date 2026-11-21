import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/wearables/metric_batch_buffer.dart';
import 'package:ixland_mobile/wearables/wearable_adapter.dart';
import 'package:ixland_mobile/wearables/whoop/whoop_ble_adapter.dart';

void main() {
  test('decodes standard 8-bit and little-endian 16-bit heart rate', () {
    expect(decodeHeartRate([0x00, 74]), 74);
    expect(decodeHeartRate([0x01, 0x2c, 0x01]), 300);
    expect(decodeHeartRate([0x06, 74]), 74);
    expect(decodeHeartRate([0x16, 74, 0x00, 0x04]), 74);
  });

  test('ignores missing values and absent sensor contact', () {
    expect(decodeHeartRate([0x00]), isNull);
    expect(decodeHeartRate([0x01, 74]), isNull);
    expect(decodeHeartRate([0x04, 74]), isNull);
    expect(decodeHeartRate([0x00, 0]), isNull);
  });

  test('uses configured UTC windows and keeps device batches apart', () {
    final buffer = MetricBatchBuffer(interval: const Duration(minutes: 3));
    MetricBatch add(int minute, int second, int bpm, [String id = 'watch-1']) =>
        buffer.addHeartRate(
          providerId: 'whoop',
          deviceId: id,
          sample: HeartRateSample(
            bpm: bpm,
            receivedAt: DateTime.utc(2026, 11, 21, 8, minute, second),
          ),
        );

    final first = add(1, 1, 65);
    expect(add(2, 59, 66), same(first));
    expect(first.startedAt, DateTime.utc(2026, 11, 21, 8));
    expect(first.duration, const Duration(minutes: 3));
    expect(first.heartRates.map((sample) => sample.bpm), [65, 66]);
    expect(add(2, 59, 70, 'watch-2').sampleCount, 1);
    expect(add(3, 0, 67).startedAt, DateTime.utc(2026, 11, 21, 8, 3));
  });
}
