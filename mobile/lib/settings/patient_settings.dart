import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final _patientIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

bool isValidPatientId(String? id) =>
    id != null && _patientIdPattern.hasMatch(id);

class PatientSettings extends ChangeNotifier {
  PatientSettings({String? defaultId})
    : _patientId = isValidPatientId(defaultId) ? defaultId : null;

  static const _channel = MethodChannel('ixland/patient_settings');
  String? _patientId;

  String? get patientId => _patientId;

  Future<void> load() async {
    final saved = await _channel.invokeMethod<String>('getPatientId');
    if (isValidPatientId(saved)) _patientId = saved;
  }

  Future<void> save(String id) async {
    if (!isValidPatientId(id)) throw ArgumentError('Invalid patient ID');
    await _channel.invokeMethod<void>('setPatientId', id);
    if (id == _patientId) return;
    _patientId = id;
    notifyListeners();
  }
}

/// Replace this implementation with patient creation through the backend.
Future<String> createPatient() async {
  final random = Random.secure();
  final suffix = List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  return 'test-$suffix';
}
