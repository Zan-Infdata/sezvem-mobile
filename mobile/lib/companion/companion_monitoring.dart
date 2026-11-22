import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../sync/monitoring_state.dart';
import 'companion_overlay.dart';

/// Tracks monitored states for the current patient and delivers their alerts.
final class CompanionMonitoring extends ChangeNotifier {
  CompanionMonitoring(this._companion);

  final CompanionOverlay _companion;
  final _states = <String, _CachedState>{};
  String? _patientId;
  int _generation = 0;
  bool _disposed = false;
  Future<void> _pending = Future.value();

  List<Map<String, Object?>> get debugStates => [
    for (final entry in _states.entries)
      {'state_id': entry.key, ...entry.value.toJson()},
  ];

  void setPatient(String? patientId) {
    if (patientId == _patientId) return;
    _generation++;
    _patientId = patientId;
    if (_states.isEmpty) return;
    _states.clear();
    notifyListeners();
  }

  Future<void> update(MonitoringSnapshot snapshot) => _enqueue((
    generation,
  ) async {
    if (snapshot.patientId != _patientId) return;
    for (final observation in snapshot.states) {
      _states.putIfAbsent(observation.id, _CachedState.new).update(observation);
    }
    notifyListeners();
    await _surfaceAlerts(generation);
  });

  Future<void> onDismissed() => _enqueue((generation) async {
    final abnormal = _states.values
        .where((state) => (state.status?.severity ?? 0) > 0)
        .toList();
    if (abnormal.isEmpty) return;
    for (final state in abnormal) {
      state.addressed = true;
    }
    notifyListeners();
    await _surfaceAlerts(generation);
  });

  Future<void> retry() => _enqueue(_surfaceAlerts);

  Future<void> _enqueue(Future<void> Function(int) action) {
    final generation = _generation;
    return _pending = _pending.then((_) async {
      if (!_isCurrent(generation)) return;
      try {
        await action(generation);
      } on PlatformException {
        // Keep pending flags when Android denies an overlay operation.
      } on MissingPluginException {
        // The overlay is available on Android only.
      }
    });
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  Future<void> _surfaceAlerts(int generation) async {
    if (!_states.values.any((state) => state.summon || state.addressed)) return;
    final showing = await _companion.isShowing();
    if (!_isCurrent(generation)) return;
    if (!showing) {
      final allowed = await _companion.hasPermission();
      if (!_isCurrent(generation) || !allowed) return;
      final shown = await _companion.show();
      if (!_isCurrent(generation) || !shown) return;
    }

    for (final state in _states.values) {
      state.summon = false;
    }
    notifyListeners();
    final addressed = _states.entries
        .where((entry) => entry.value.addressed)
        .toList();
    if (addressed.isEmpty) return;
    final shown = await _companion.showAlert(
      title: 'Monitoring states',
      message: addressed
          .map((entry) => '${entry.key}: ${entry.value.description}')
          .join('\n'),
    );
    if (!_isCurrent(generation) || !shown) return;
    for (final entry in addressed) {
      entry.value.addressed = false;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final class _CachedState {
  MonitoringStatus? status;
  MonitoringStatus? previousStatus;
  DateTime? updatedAt;
  bool summon = false;
  bool addressed = false;
  bool resolved = false;

  void update(MonitoringState observation) {
    final lastUpdate = updatedAt;
    final nextUpdate = observation.updatedAt;
    if (lastUpdate != null &&
        nextUpdate != null &&
        nextUpdate.isBefore(lastUpdate)) {
      return;
    }
    updatedAt = nextUpdate;
    final next = observation.status;
    if (status == next) return;
    final severity = status?.severity ?? 0;
    if (!resolved || severity > (previousStatus?.severity ?? -1)) {
      previousStatus = status;
    }
    status = next;
    if (!resolved && (next?.severity ?? 0) > severity) {
      summon = true;
      addressed = true;
      resolved = true;
    }
  }

  String get description {
    final current = status?.name ?? 'unassessed';
    final previous = previousStatus;
    return previous != null && previous.severity > (status?.severity ?? 0)
        ? '$current (previously ${previous.name})'
        : current;
  }

  Map<String, Object?> toJson() => {
    'status': status?.name,
    'previous_status': previousStatus?.name,
    'summon': summon,
    'addressed': addressed,
    'resolved': resolved,
  };
}
