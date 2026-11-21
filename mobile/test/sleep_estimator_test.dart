import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/sync/telemetry_api.dart';
import 'package:ixland_mobile/wearables/metric_batch_buffer.dart';
import 'package:ixland_mobile/wearables/sleep_estimator.dart';
import 'package:ixland_mobile/wearables/wearable_adapter.dart';

void main() {
  final start = DateTime.utc(2026, 11, 21, 23, 30);
  DateTime minute(int offset) => start.add(Duration(minutes: offset));

  test('estimates an overnight window once sustained wake is observed', () {
    final estimator = SleepEstimator();
    _recordMinutes(estimator.add, minute(0), 30, 60);
    _recordMinutes(estimator.add, minute(30), 5, 85);
    _recordMinutes(estimator.add, minute(35), 35, 61);
    expect(estimator.completeBefore(minute(70)), isEmpty);

    _recordMinutes(estimator.add, minute(70), 15, 80);
    expect(estimator.completeBefore(minute(84)), isEmpty);
    expect(estimator.completeBefore(minute(85)), [
      (start: minute(0), end: minute(70)),
    ]);
    expect(estimator.completeBefore(minute(86)), isEmpty);
  });

  test('a long missing stretch or sparse reading cannot close sleep', () {
    final estimator = SleepEstimator();
    _recordMinutes(estimator.add, minute(0), 65, 60);
    for (var i = 65; i < 85; i++) {
      estimator.add(HeartRateSample(bpm: 85, receivedAt: minute(i)));
    }
    expect(estimator.completeBefore(minute(85)), isEmpty);
    _recordMinutes(estimator.add, minute(85), 20, 85);
    expect(estimator.completeBefore(minute(105)), isEmpty);
  });

  test(
    'keeps sleep history across uploads and sends each session once',
    () async {
      const interval = Duration(seconds: 10);
      final buffer = MetricBatchBuffer(interval: interval);
      final api = TelemetryApi(url: 'https://example.test/batches');
      final attempts = <Map<String, Object?>>[];
      void add(HeartRateSample sample) => buffer.addSample(
        patientId: 'fixture-patient',
        providerId: 'whoop',
        deviceId: 'strap',
        sample: sample,
      );
      Future<void> flush(
        DateTime now, {
        bool accepted = true,
        bool lost = false,
      }) => buffer.flushReady(
        now: now,
        send: (payload) async {
          attempts.add(payload);
          if (lost) throw StateError('Response lost');
          return accepted;
        },
      );

      _recordMinutes(add, minute(0), 65, 60);
      await flush(minute(65));
      expect(attempts.last['sleep_start'], isNull);
      expect(attempts.last['sleep_end'], isNull);
      expect(
        buffer.pendingSampleCount(providerId: 'whoop', deviceId: 'strap'),
        0,
      );

      _recordMinutes(add, minute(65), 15, 80);
      await flush(minute(79).add(const Duration(seconds: 50)));
      expect(attempts.last['sleep_start'], isNull);

      // The last BPM readings already uploaded before the wake minute closed.
      await flush(minute(80), accepted: false);
      final rejected = attempts.last;
      expect(rejected['hr'], isEmpty);
      expect(rejected['sample_timestamps'], isEmpty);
      final wire = api.payloadFor(rejected);
      expect(wire['extra'], {
        'batch_interval_in_seconds': 10,
        'sleep_start': minute(0).toIso8601String(),
        'sleep_end': minute(65).toIso8601String(),
      });

      _recordMinutes(add, minute(80), 1, 80);
      await flush(minute(81), lost: true);
      final unconfirmed = attempts.last;
      expect(unconfirmed['b_number'], rejected['b_number']);
      expect(unconfirmed['sleep_start'], rejected['sleep_start']);
      expect(unconfirmed['sleep_end'], rejected['sleep_end']);
      expect(unconfirmed['hr'], [80, 80, 120]);

      _recordMinutes(add, minute(81), 1, 85);
      await flush(minute(82));
      expect(attempts.last, same(unconfirmed));
      await flush(minute(83));
      expect(attempts.last['hr'], [85, 85, 120]);
      final extra = api.payloadFor(attempts.last)['extra'] as Map;
      expect(extra.containsKey('sleep_start'), isFalse);
      expect(extra.containsKey('sleep_end'), isFalse);
    },
  );

  test('does not join readings across patient or device IDs', () async {
    final buffer = MetricBatchBuffer(interval: const Duration(minutes: 1));
    void recordFor(String patientId, String deviceId, int from, int count) {
      _recordMinutes(
        (sample) => buffer.addSample(
          patientId: patientId,
          providerId: 'samsung',
          deviceId: deviceId,
          sample: sample,
        ),
        minute(from),
        count,
        from == 0 ? 60 : 85,
      );
    }

    recordFor('fixture-a', 'watch-a', 0, 65);
    recordFor('fixture-b', 'watch-a', 65, 15);
    recordFor('fixture-a', 'watch-b', 65, 15);
    final attempts = <Map<String, Object?>>[];
    await buffer.flushReady(
      now: minute(80),
      send: (payload) async {
        attempts.add(payload);
        return true;
      },
    );
    expect(attempts, hasLength(3));
    expect(
      attempts.map((payload) => payload['sleep_start']),
      everyElement(isNull),
    );
    expect(
      attempts.map((payload) => payload['sleep_end']),
      everyElement(isNull),
    );
  });
}

void _recordMinutes(
  void Function(HeartRateSample) record,
  DateTime start,
  int count,
  int bpm,
) {
  for (var minute = 0; minute < count; minute++) {
    for (final (second, reading) in [(2, bpm), (8, bpm), (14, 120)]) {
      record(
        HeartRateSample(
          bpm: reading,
          receivedAt: start.add(Duration(minutes: minute, seconds: second)),
        ),
      );
    }
  }
}
