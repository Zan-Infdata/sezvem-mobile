import 'dart:convert';

import 'package:flutter/material.dart';

import '../sync/telemetry_api.dart';
import '../wearables/metric_batch_buffer.dart';
import '../wearables/wearable_adapter.dart';

Future<({double averageBpm, Map<String, Object?> body})> replaySimulatedNight(
  DateTime date,
) async {
  final local = date.toLocal();
  final start = DateTime(local.year, local.month, local.day - 1, 23, 14);
  final wake = DateTime(local.year, local.month, local.day, 6, 57);
  final buffer = MetricBatchBuffer(interval: const Duration(minutes: 1));
  var totalBpm = 0;
  var sampleCount = 0;
  Map<String, Object?>? sleepBatch;

  void record(DateTime minute, List<int> readings, {bool asleep = false}) {
    for (final (index, bpm) in readings.indexed) {
      buffer.addSample(
        patientId: 'simulated-night',
        providerId: 'whoop',
        deviceId: 'simulated-strap',
        sample: HeartRateSample(
          bpm: bpm,
          receivedAt: minute.add(Duration(seconds: 20 * index)),
        ),
      );
      if (asleep) {
        totalBpm += bpm;
        sampleCount++;
      }
    }
  }

  Future<bool> capture(Map<String, Object?> batch) async {
    if (batch['sleep_end'] != null) sleepBatch = batch;
    return true;
  }

  for (var minute = start; minute.isBefore(wake);) {
    record(minute, const [52, 53, 54], asleep: true);
    minute = minute.add(const Duration(minutes: 1));
  }
  await buffer.flushReady(now: wake, send: capture);

  // The estimator requires 15 closed minutes of higher BPM to confirm waking.
  for (var index = 0; index < 15; index++) {
    final minute = wake.add(Duration(minutes: index));
    record(minute, const [71, 72, 73]);
    await buffer.flushReady(
      now: minute.add(const Duration(minutes: 1)),
      send: capture,
    );
  }
  final batch = sleepBatch;
  if (batch == null) {
    throw StateError('The estimator produced no sleep window.');
  }
  return (
    averageBpm: totalBpm / sampleCount,
    body: TelemetryApi(url: '').payloadFor(batch),
  );
}

class SimulatedNightScreen extends StatefulWidget {
  const SimulatedNightScreen({super.key});

  @override
  State<SimulatedNightScreen> createState() => _SimulatedNightScreenState();
}

class _SimulatedNightScreenState extends State<SimulatedNightScreen> {
  late final _replay = replaySimulatedNight(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final locale = MaterialLocalizations.of(context);
    String format(String iso) {
      final local = DateTime.parse(iso).toLocal();
      final date = locale.formatMediumDate(local);
      final time = locale.formatTimeOfDay(
        TimeOfDay.fromDateTime(local),
        alwaysUse24HourFormat: true,
      );
      return '$date $time';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Simulated night')),
      body: FutureBuilder(
        future: _replay,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('No sleep estimate was generated.'),
            );
          }
          final replay = snapshot.data;
          if (replay == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final extra = replay.body['extra'] as Map<String, Object?>;
          final start = format(extra['sleep_start'] as String);
          final end = format(extra['sleep_end'] as String);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Local replay. Uploads disabled.'),
              const SizedBox(height: 12),
              Text('Sleep start  $start'),
              Text('Sleep end  $end'),
              Text(
                'Average sleeping heart rate  ${replay.averageBpm.toStringAsFixed(0)} BPM',
              ),
              const SizedBox(height: 16),
              const Text('Batch JSON (debug)'),
              SelectableText(
                const JsonEncoder.withIndent('  ').convert(replay.body),
              ),
            ],
          );
        },
      ),
    );
  }
}
