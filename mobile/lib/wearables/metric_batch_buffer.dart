import 'wearable_adapter.dart';

/// True acknowledges the batch. False confirms it was not accepted.
/// Throw when acceptance is unknown so the exact payload can be retried.
typedef MetricBatchSender = Future<bool> Function(Map<String, Object?> payload);

final class MetricBatch {
  MetricBatch._(this.providerId, this.deviceId, this.startedAt, this.duration);

  final String providerId;
  final String deviceId;
  final DateTime startedAt;
  final Duration duration;
  final List<HeartRateSample> _heartRates = [];

  List<HeartRateSample> get heartRates => List.unmodifiable(_heartRates);
  int get sampleCount => _heartRates.length;
}

final class MetricBatchBuffer {
  MetricBatchBuffer({required this.interval, int firstBatchNumber = 1})
    : _nextBatchNumber = firstBatchNumber {
    if (interval.inSeconds < 1) {
      throw ArgumentError.value(interval, 'interval', 'Must be positive');
    }
  }

  final Duration interval;
  final _connections = <(String?, String, String), _ConnectionBuffer>{};
  int _nextBatchNumber;
  bool _flushing = false;

  DateTime windowStart(DateTime time) {
    final width = interval.inMilliseconds;
    final timestamp = time.millisecondsSinceEpoch;
    return DateTime.fromMillisecondsSinceEpoch(
      timestamp - timestamp % width,
      isUtc: true,
    );
  }

  MetricBatch addHeartRate({
    String? patientId,
    required String providerId,
    required String deviceId,
    required HeartRateSample sample,
  }) {
    final startedAt = windowStart(sample.receivedAt);
    final connection = _connections.putIfAbsent((
      patientId,
      providerId,
      deviceId,
    ), _ConnectionBuffer.new);
    final batch = connection.windows.putIfAbsent(
      startedAt,
      () => MetricBatch._(providerId, deviceId, startedAt, interval),
    );
    batch._heartRates.add(sample);
    return batch;
  }

  int pendingSampleCount({
    required String providerId,
    required String deviceId,
  }) {
    return _connections.entries
        .where(
          (entry) => entry.key.$2 == providerId && entry.key.$3 == deviceId,
        )
        .expand((entry) => entry.value.windows.values)
        .fold(0, (count, window) => count + window.sampleCount);
  }

  /// Called when the first patient ID is set, before adding readings for it.
  void assignUnassignedReadings(String patientId) {
    final unassigned = _connections.keys
        .where((key) => key.$1 == null)
        .toList();
    for (final key in unassigned) {
      final connection = _connections.remove(key)!;
      _connections[(patientId, key.$2, key.$3)] = connection;
    }
  }

  Future<void> flushReady({
    required DateTime now,
    required MetricBatchSender send,
  }) async {
    if (_flushing) return;
    _flushing = true;
    final boundary = windowStart(now);
    try {
      // A new device can start feeding the buffer while a send is in flight.
      for (final entry in _connections.entries.toList()) {
        final connection = entry.value;
        var attempt = connection.unconfirmed;
        if (attempt == null) {
          final windows = connection.windows.values
              .where((window) => window.startedAt.isBefore(boundary))
              .toList();
          if (windows.isEmpty) continue;
          windows.sort((a, b) => a.startedAt.compareTo(b.startedAt));
          final number = connection.batchNumber ??= _nextBatchNumber++;
          attempt = _BatchAttempt(windows, number, entry.key.$1);
        }

        final bool accepted;
        try {
          accepted = await send(attempt.payload);
        } catch (_) {
          connection.unconfirmed = attempt;
          continue;
        }
        if (!accepted) continue;

        connection.unconfirmed = null;
        connection.batchNumber = null;
        for (final entry in attempt.sampleCounts.entries) {
          final window = entry.key;
          // Leave samples that arrived after this payload was created.
          window._heartRates.removeRange(0, entry.value);
          if (window.sampleCount == 0) {
            connection.windows.remove(window.startedAt);
          }
        }
        if (connection.windows.isEmpty) _connections.remove(entry.key);
      }
    } finally {
      _flushing = false;
    }
  }
}

final class _ConnectionBuffer {
  final windows = <DateTime, MetricBatch>{};
  int? batchNumber;
  _BatchAttempt? unconfirmed;
}

final class _BatchAttempt {
  _BatchAttempt(List<MetricBatch> windows, int batchNumber, String? patientId)
    : sampleCounts = {for (final window in windows) window: window.sampleCount},
      payload = Map.unmodifiable({
        'patient_id': patientId,
        'batch_timestamp': windows.first.startedAt.toIso8601String(),
        'b_number': batchNumber,
        'hr': List<int>.unmodifiable(
          windows.expand(
            (window) => window._heartRates.map((sample) => sample.bpm),
          ),
        ),
        'sleep_start': null,
        'sleep_end': null,
        'temperature': const <double>[],
        'steps': null,
        'spo2': null,
        'batch_interval_in_seconds': windows.last.startedAt
            .add(windows.last.duration)
            .difference(windows.first.startedAt)
            .inSeconds,
      });

  final Map<MetricBatch, int> sampleCounts;
  final Map<String, Object?> payload;
}
