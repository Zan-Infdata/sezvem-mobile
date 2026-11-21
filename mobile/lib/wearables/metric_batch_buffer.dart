import 'wearable_adapter.dart';

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
  MetricBatchBuffer({required this.interval}) {
    if (interval.inSeconds < 1) {
      throw ArgumentError.value(interval, 'interval', 'Must be positive');
    }
  }

  final Duration interval;
  final _batches = <(String, String, DateTime), MetricBatch>{};
  static const _maxBatches = 24;

  MetricBatch addHeartRate({
    required String providerId,
    required String deviceId,
    required HeartRateSample sample,
  }) {
    final width = interval.inMilliseconds;
    final timestamp = sample.receivedAt.millisecondsSinceEpoch;
    final startedAt = DateTime.fromMillisecondsSinceEpoch(
      timestamp - timestamp % width,
      isUtc: true,
    );
    final key = (providerId, deviceId, startedAt);
    final batch = _batches.putIfAbsent(
      key,
      () => MetricBatch._(providerId, deviceId, startedAt, interval),
    );
    batch._heartRates.add(sample);
    if (_batches.length > _maxBatches) {
      _batches.remove(_batches.keys.first);
    }
    return batch;
  }
}
