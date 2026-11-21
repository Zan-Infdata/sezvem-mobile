import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../settings/patient_settings.dart';

typedef TelemetryUploadResult = ({bool accepted, String status});

final class TelemetryDeliveryUncertain implements Exception {
  const TelemetryDeliveryUncertain(this.message);

  final String message;
}

class TelemetryApi {
  TelemetryApi({required String url}) : _endpoint = Uri.tryParse(url);

  final Uri? _endpoint;
  final _unconfirmed = <(String, int)>{};
  static const _timeout = Duration(seconds: 10);

  Map<String, Object?> payloadFor(Map<String, Object?> batch) {
    final temperatures = (batch['temperature'] as List<double>)
        .where((celsius) => celsius >= 30 && celsius <= 45)
        .toList();
    final total = temperatures.fold(0.0, (sum, celsius) => sum + celsius);
    // Keep an exact tenth from rounding up because of floating-point noise.
    final temperature = temperatures.isEmpty
        ? null
        : (total / temperatures.length * 10 - 1e-9).ceil() / 10;
    final heartRates = (batch['hr'] as List<int>)
        .where((value) => value >= 20 && value <= 250)
        .toList();
    return {
      'patient_id': batch['patient_id'],
      'batch_timestamp': batch['batch_timestamp'],
      'batch_number': batch['b_number'],
      if (heartRates.isNotEmpty) 'hr': heartRates,
      if (temperature != null) 'temperature': temperature,
      if (batch['steps'] case final int steps when steps >= 0) 'steps': steps,
      if (batch['spo2'] case final int spo2 when spo2 >= 50 && spo2 <= 100)
        'spo2': spo2,
      'extra': {
        'batch_interval_in_seconds': batch['batch_interval_in_seconds'],
        if (batch['sleep_start'] case final String start) 'sleep_start': start,
        if (batch['sleep_end'] case final String end) 'sleep_end': end,
      },
    };
  }

  Future<TelemetryUploadResult> send(Map<String, Object?> payload) async {
    final patientId = payload['patient_id'];
    if (patientId is! String || !isValidPatientId(patientId)) {
      return (
        accepted: false,
        status: 'Set a Patient ID in Settings to upload.',
      );
    }
    final endpoint = _endpoint;
    if (endpoint == null ||
        (endpoint.scheme != 'https' && endpoint.scheme != 'http') ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasFragment) {
      return (accepted: false, status: 'Set a valid BATCH_API_URL to upload.');
    }

    final batchKey = (patientId, payload['batch_number'] as int);
    final body = utf8.encode(jsonEncode(payload));
    final client = HttpClient()..connectionTimeout = _timeout;
    var deliveryStarted = false;
    try {
      final request = await client.postUrl(endpoint).timeout(_timeout);
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.contentLength = body.length;
      deliveryStarted = true;
      request.add(body);
      final response = await request.close().timeout(_timeout);
      final status = response.statusCode;
      if (status == HttpStatus.created) {
        _unconfirmed.remove(batchKey);
        return (accepted: true, status: 'Uploaded (HTTP 201).');
      }
      if (status == HttpStatus.conflict && _unconfirmed.contains(batchKey)) {
        final body = await utf8.decoder.bind(response).join().timeout(_timeout);
        final error = jsonDecode(body);
        if (error case {'error': {'code': 'conflict'}}) {
          _unconfirmed.remove(batchKey);
          return (accepted: true, status: 'Upload already stored (HTTP 409).');
        }
      }
      if (status >= 500 || status == HttpStatus.requestTimeout) {
        _unconfirmed.add(batchKey);
        throw TelemetryDeliveryUncertain('Upload unconfirmed (HTTP $status).');
      }
      return (accepted: false, status: 'Upload rejected (HTTP $status).');
    } on TimeoutException {
      return _transportFailure(batchKey, deliveryStarted);
    } on IOException {
      return _transportFailure(batchKey, deliveryStarted);
    } on FormatException {
      return _transportFailure(batchKey, deliveryStarted);
    } finally {
      client.close(force: true);
    }
  }

  TelemetryUploadResult _transportFailure(
    (String, int) batchKey,
    bool deliveryStarted,
  ) {
    if (deliveryStarted) {
      _unconfirmed.add(batchKey);
      throw const TelemetryDeliveryUncertain('Upload unconfirmed. Retrying.');
    }
    return (accepted: false, status: 'API unreachable. Batch kept.');
  }
}
