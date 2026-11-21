import 'dart:collection';

import 'wearable_adapter.dart';

typedef EstimatedSleepSession = ({DateTime start, DateTime end});

/// Estimates a sleep window from sustained low heart rate and observed wake.
/// Use a separate instance for each patient and source device.
final class SleepEstimator {
  static const _historyMinutes = 24 * 60;
  static const _minSamplesPerMinute = 3;
  static const _minSleepMinutes = 60;
  static const _wakeConfirmationMinutes = 15;
  static const _maxMissingMinutes = 5;
  static const _lowHeartRatePercentile = 0.10;
  static const _sleepBandMultiplier = 1.05;

  final _readings = SplayTreeMap<int, List<int>>();
  int? _lastEvaluatedMinute;
  int? _confirmedThroughMinute;

  bool get isEmpty => _readings.isEmpty;

  void add(HeartRateSample sample) {
    if (sample.bpm < 20 || sample.bpm > 250) return;
    final minute = _minuteOf(sample.receivedAt);
    (_readings[minute] ??= []).add(sample.bpm);
  }

  List<EstimatedSleepSession> completeBefore(DateTime cutoff) {
    final cutoffMinute = _minuteOf(cutoff);
    final lastEvaluated = _lastEvaluatedMinute;
    if (lastEvaluated != null && cutoffMinute <= lastEvaluated) return [];
    _lastEvaluatedMinute = cutoffMinute;

    final oldest = cutoffMinute - _historyMinutes;
    var first = _readings.firstKey();
    while (first != null && first < oldest) {
      _readings.remove(first);
      first = _readings.firstKey();
    }
    final minutes = [
      for (final entry in _readings.entries)
        if (entry.key < cutoffMinute &&
            entry.value.length >= _minSamplesPerMinute)
          (minute: entry.key, bpm: _median(entry.value)),
    ];
    if (minutes.length < _minSleepMinutes + _wakeConfirmationMinutes) return [];

    // Give every covered minute equal weight regardless of sensor cadence.
    final ordered = minutes.map((reading) => reading.bpm).toList()..sort();
    final lowIndex = ((ordered.length - 1) * _lowHeartRatePercentile).floor();
    final sleepThreshold = ordered[lowIndex] * _sleepBandMultiplier;
    final confirmedThrough = _confirmedThroughMinute;
    final sessions = <EstimatedSleepSession>[];
    var previous = oldest - 1;
    int? start;
    int? wakeStart;
    var lowMinutes = 0;

    for (final reading in minutes) {
      final minute = reading.minute;
      if (confirmedThrough != null && minute <= confirmedThrough) continue;
      if (minute - previous > _maxMissingMinutes + 1) {
        start = null;
        lowMinutes = 0;
      }
      if (minute != previous + 1) wakeStart = null;
      previous = minute;

      if (reading.bpm <= sleepThreshold) {
        start ??= minute;
        lowMinutes++;
        wakeStart = null;
        continue;
      }
      if (start == null) continue;
      wakeStart ??= minute;
      if (minute - wakeStart + 1 < _wakeConfirmationMinutes) continue;
      if (lowMinutes >= _minSleepMinutes) {
        sessions.add((start: _minuteTime(start), end: _minuteTime(wakeStart)));
        _confirmedThroughMinute = minute;
      }
      start = null;
      lowMinutes = 0;
      wakeStart = null;
    }
    return sessions;
  }

  static int _minuteOf(DateTime time) =>
      time.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute;

  static DateTime _minuteTime(int minute) =>
      DateTime.fromMillisecondsSinceEpoch(
        minute * Duration.millisecondsPerMinute,
        isUtc: true,
      );

  static double _median(List<int> readings) {
    readings.sort();
    final middle = readings.length ~/ 2;
    return (readings[(readings.length - 1) ~/ 2] + readings[middle]) / 2;
  }
}
