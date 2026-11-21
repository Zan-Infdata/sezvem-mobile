import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../settings/patient_settings.dart';

final class PatientCreationException implements Exception {
  const PatientCreationException(this.message);

  final String message;
}

class PatientApi {
  PatientApi({required String batchUrl}) : _endpoint = _patientsUrl(batchUrl);

  static const _timeout = Duration(seconds: 10);
  final Uri? _endpoint;

  static Uri? _patientsUrl(String batchUrl) {
    final uri = Uri.tryParse(batchUrl);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return null;
    }
    final segments = uri.pathSegments.toList();
    if (segments.isNotEmpty && segments.last.isEmpty) segments.removeLast();
    if (segments.isEmpty) return null;
    segments[segments.length - 1] = 'patients';
    return uri.replace(pathSegments: segments);
  }

  Future<String> createPatient() async {
    final endpoint = _endpoint;
    if (endpoint == null) {
      throw const PatientCreationException('Set a valid BATCH_API_URL.');
    }
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.postUrl(endpoint).timeout(_timeout);
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'name': 'IXLand patient'}));
      final response = await request.close().timeout(_timeout);
      final status = response.statusCode;
      if (status >= 500 || status == HttpStatus.requestTimeout) {
        throw PatientCreationException(
          'Could not confirm patient creation (HTTP $status).',
        );
      }
      if (status != HttpStatus.created) {
        throw PatientCreationException(
          'Could not create patient (HTTP $status).',
        );
      }
      final body = await utf8.decoder.bind(response).join().timeout(_timeout);
      final decoded = jsonDecode(body);
      if (decoded case {
        'patient_id': final String id,
      } when isValidPatientId(id)) {
        return id;
      }
      throw const FormatException('Missing or invalid patient_id');
    } on TimeoutException {
      throw const PatientCreationException(
        'Could not confirm patient creation before timeout.',
      );
    } on IOException {
      throw const PatientCreationException(
        'Could not confirm patient creation. Check the connection.',
      );
    } on FormatException {
      throw const PatientCreationException(
        'The API did not return a valid patient ID.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
