import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/debug/simulated_night_screen.dart';

void main() {
  test('replays the requested local sleep window and 53 BPM average', () async {
    final date = DateTime(2026, 11, 22);
    final replay = await replaySimulatedNight(date);
    expect(replay.averageBpm, 53);
    expect(replay.body['patient_id'], 'simulated-night');
    expect(replay.body['hr'], [71, 72, 73]);
    expect(replay.body['extra'], {
      'batch_interval_in_seconds': 60,
      'sleep_start': DateTime(2026, 11, 21, 23, 14).toUtc().toIso8601String(),
      'sleep_end': DateTime(2026, 11, 22, 6, 57).toUtc().toIso8601String(),
    });
  });
}
