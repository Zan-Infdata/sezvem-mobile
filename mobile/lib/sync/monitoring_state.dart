enum MonitoringStatus {
  normal(0),
  warning(1),
  unbalanced(1),
  critical(2),
  low(2);

  const MonitoringStatus(this.severity);

  final int severity;

  static MonitoringStatus? fromOutput(Map<Object?, Object?> output) {
    final value = output.containsKey('status')
        ? output['status']
        : output['stage'];
    return switch (value) {
      'normal' => normal,
      'warning' => warning,
      'unbalanced' => unbalanced,
      'critical' => critical,
      'low' => low,
      _ => null,
    };
  }
}

final class MonitoringState {
  const MonitoringState({
    required this.id,
    required this.status,
    this.updatedAt,
  });

  final String id;
  final MonitoringStatus? status;
  final DateTime? updatedAt;

  static MonitoringState? fromJson(Object? json, String patientId) {
    if (json case {
      'patient_id': final String owner,
      'state_id': final String id,
      'output': final Map<Object?, Object?> output,
    } when owner == patientId && id.isNotEmpty) {
      final timestamp = json['updated_at'];
      return MonitoringState(
        id: id,
        status: MonitoringStatus.fromOutput(output),
        updatedAt: timestamp is String ? DateTime.tryParse(timestamp) : null,
      );
    }
    return null;
  }
}

typedef MonitoringSnapshot = ({String patientId, List<MonitoringState> states});
