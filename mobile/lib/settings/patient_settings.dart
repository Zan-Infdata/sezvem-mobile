import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final _patientIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

bool isValidPatientId(String? id) =>
    id != null && _patientIdPattern.hasMatch(id);

class PatientSettings extends ChangeNotifier {
  PatientSettings({String? defaultId, Future<String> Function()? createPatient})
    : _patientId = isValidPatientId(defaultId) ? defaultId : null,
      _createPatient = createPatient;

  static const _channel = MethodChannel('ixland/patient_settings');
  final Future<String> Function()? _createPatient;
  String? _patientId;
  String? _createdIdPendingSave;
  Future<String>? _creation;

  String? get patientId => _patientId;
  bool get canCreatePatient => _createPatient != null;

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

  Future<String> createPatient() async {
    if (_creation case final pending?) return pending;
    final create = _createPatient;
    if (create == null) throw StateError('Patient creation is unavailable.');
    final creation = _createAndSave(create);
    _creation = creation;
    try {
      return await creation;
    } finally {
      _creation = null;
    }
  }

  Future<String> _createAndSave(Future<String> Function() create) async {
    final id = _createdIdPendingSave ??= await create();
    await save(id);
    _createdIdPendingSave = null;
    return id;
  }
}
