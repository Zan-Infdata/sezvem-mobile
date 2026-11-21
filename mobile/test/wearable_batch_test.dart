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
        buffer.addSample(
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

  test(
    'extends a rejected batch and clears it only after acceptance',
    () async {
      final buffer = MetricBatchBuffer(interval: const Duration(minutes: 5));
      final start = DateTime.utc(2026, 11, 21, 8);
      final attempts = <Map<String, Object?>>[];

      void addReading(int minute, int bpm) => buffer.addSample(
        providerId: 'whoop',
        deviceId: 'strap',
        sample: HeartRateSample(
          bpm: bpm,
          receivedAt: start.add(Duration(minutes: minute)),
        ),
      );

      Future<void> flush(int minute, {required bool accepted}) =>
          buffer.flushReady(
            now: start.add(Duration(minutes: minute)),
            send: (payload) async {
              attempts.add(payload);
              return accepted;
            },
          );

      addReading(1, 72);
      await flush(4, accepted: true);
      expect(attempts, isEmpty);

      await flush(5, accepted: false);
      expect(attempts.single['hr'], [72]);
      expect(attempts.single['batch_interval_in_seconds'], 300);

      addReading(6, 75);
      await flush(10, accepted: true);
      expect(attempts.last, {
        'patient_id': null,
        'batch_timestamp': start.toIso8601String(),
        'b_number': attempts.first['b_number'],
        'hr': [72, 75],
        'sample_timestamps': [
          start.add(const Duration(minutes: 1)).toIso8601String(),
          start.add(const Duration(minutes: 6)).toIso8601String(),
        ],
        'sleep_start': null,
        'sleep_end': null,
        'temperature': [],
        'steps': null,
        'spo2': null,
        'batch_interval_in_seconds': 600,
      });
      expect(
        buffer.pendingSampleCount(providerId: 'whoop', deviceId: 'strap'),
        0,
      );
      await flush(15, accepted: true);
      expect(attempts, hasLength(2));

      addReading(16, 76);
      await flush(20, accepted: true);
      expect(attempts.last['b_number'], 2);
      expect(attempts.last['hr'], [76]);
      expect(attempts.last['batch_interval_in_seconds'], 300);
    },
  );

  test('retries an unconfirmed payload and retains newer readings', () async {
    final buffer = MetricBatchBuffer(interval: const Duration(minutes: 5));
    final start = DateTime.utc(2026, 11, 21, 8);
    final attempts = <Map<String, Object?>>[];

    void addReading(int minute, int bpm) => buffer.addSample(
      providerId: 'samsung',
      deviceId: 'watch',
      sample: HeartRateSample(
        bpm: bpm,
        receivedAt: start.add(Duration(minutes: minute)),
      ),
    );

    addReading(1, 70);
    await buffer.flushReady(
      now: start.add(const Duration(minutes: 5)),
      send: (payload) async {
        attempts.add(payload);
        addReading(4, 71);
        throw StateError('Response lost');
      },
    );

    Future<void> accept(int minute) => buffer.flushReady(
      now: start.add(Duration(minutes: minute)),
      send: (payload) async {
        attempts.add(payload);
        return true;
      },
    );

    addReading(6, 73);
    await buffer.flushReady(
      now: start.add(const Duration(minutes: 10)),
      send: (payload) async {
        expect(payload, same(attempts.first));
        return false; // The debug jam blocks this retry before it reaches the API.
      },
    );
    await accept(10);
    expect(attempts.last, same(attempts.first));
    expect(attempts.last['hr'], [70]);
    expect(attempts.last['sample_timestamps'], [
      start.add(const Duration(minutes: 1)).toIso8601String(),
    ]);
    expect(
      buffer.pendingSampleCount(providerId: 'samsung', deviceId: 'watch'),
      2,
    );

    await accept(15);
    expect(attempts.last['hr'], [71, 73]);
    expect(attempts.last['sample_timestamps'], [
      start.add(const Duration(minutes: 4)).toIso8601String(),
      start.add(const Duration(minutes: 6)).toIso8601String(),
    ]);
    expect(attempts.last['b_number'], 2);
  });

  test('assigns buffered readings to the first patient ID', () async {
    final interval = const Duration(seconds: 10);
    final buffer = MetricBatchBuffer(interval: interval);
    final start = DateTime.utc(2026, 11, 21, 8);
    final attempts = <Map<String, Object?>>[];
    buffer.addSample(
      providerId: 'whoop',
      deviceId: 'strap',
      sample: HeartRateSample(bpm: 70, receivedAt: start),
    );
    await buffer.flushReady(
      now: start.add(interval),
      send: (payload) async {
        attempts.add(payload);
        return false;
      },
    );
    expect(attempts.single['patient_id'], isNull);
    buffer.assignUnassignedReadings('first-patient');
    await buffer.flushReady(
      now: start.add(interval),
      send: (payload) async {
        attempts.add(payload);
        return true;
      },
    );
    expect(attempts.last, {...attempts.first, 'patient_id': 'first-patient'});
  });

  test(
    'merges temperature readings and keeps the latest cumulative steps',
    () async {
      const interval = Duration(seconds: 10);
      final buffer = MetricBatchBuffer(interval: interval);
      final start = DateTime.utc(2026, 11, 21, 8);
      final end = start.add(interval);
      void add(WearableSample sample) => buffer.addSample(
        providerId: 'samsung',
        deviceId: 'watch',
        sample: sample,
      );

      add(TemperatureSample(celsius: 34.1, receivedAt: start));
      add(StepCountSample(count: 1024, receivedAt: start));
      await buffer.flushReady(
        now: end,
        send: (payload) async {
          expect(payload['steps'], 1024);
          return false;
        },
      );

      // A watch reboot can reset the reported count.
      add(StepCountSample(count: 0, receivedAt: end));
      add(TemperatureSample(celsius: 34.2, receivedAt: end));
      await buffer.flushReady(
        now: end.add(interval),
        send: (payload) async {
          expect(payload['steps'], 0);
          expect(payload['temperature'], [34.1, 34.2]);
          expect(payload['hr'], isEmpty);
          expect(payload['sample_timestamps'], isEmpty);
          return true;
        },
      );
      expect(
        buffer.pendingSampleCount(providerId: 'samsung', deviceId: 'watch'),
        0,
      );
    },
  );
}
