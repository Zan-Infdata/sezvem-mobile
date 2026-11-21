import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/sync/telemetry_api.dart';

void main() {
  test(
    'posts the mapped batch and distinguishes rejection from storage',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requests =
          <({String method, String path, String? mimeType, Object? body})>[];
      var status = HttpStatus.created;
      server.listen((request) async {
        requests.add((
          method: request.method,
          path: request.uri.path,
          mimeType: request.headers.contentType?.mimeType,
          body: jsonDecode(await utf8.decoder.bind(request).join()),
        ));
        request.response.statusCode = status;
        if (status == HttpStatus.conflict) {
          request.response.write('{"error":{"code":"conflict"}}');
        }
        await request.response.close();
      });

      final api = TelemetryApi(
        url: 'http://127.0.0.1:${server.port}/api/batches',
      );
      final payload = api.payloadFor({
        'patient_id': 'fixture-patient',
        'b_number': 42,
        'batch_timestamp': '2026-11-21T18:00:00Z',
        'batch_interval_in_seconds': 120,
        'hr': [14, 71, 72, 251],
        'temperature': <double>[],
        'steps': null,
        'spo2': null,
      });
      expect(payload, {
        'patient_id': 'fixture-patient',
        'batch_number': 42,
        'batch_timestamp': '2026-11-21T18:00:00Z',
        'hr': [71, 72],
        'extra': {'batch_interval_in_seconds': 120},
      });

      expect((await api.send(payload)).accepted, isTrue);
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/batches');
      expect(request.mimeType, 'application/json');
      expect(request.body, payload);

      status = HttpStatus.conflict;
      expect((await api.send(payload)).accepted, isFalse);
      status = HttpStatus.unprocessableEntity;
      expect((await api.send(payload)).accepted, isFalse);

      status = HttpStatus.internalServerError;
      await expectLater(
        api.send(payload),
        throwsA(isA<TelemetryDeliveryUncertain>()),
      );
      status = HttpStatus.conflict;
      expect(
        (await api.send({...payload, 'patient_id': 'other-patient'})).accepted,
        isFalse,
      );
      expect((await api.send(payload)).accepted, isTrue);
      expect(requests.last.body, payload);
    },
  );

  test('requires explicit patient and endpoint configuration', () async {
    final noPatient = TelemetryApi(url: 'https://example.test/batches');
    final noEndpoint = TelemetryApi(url: 'invalid');
    expect((await noPatient.send({})).accepted, isFalse);
    expect(
      (await noEndpoint.send({'patient_id': 'fixture-patient'})).accepted,
      isFalse,
    );
  });

  test('maps temperatures to a rounded-up mean and sends cumulative steps', () {
    final api = TelemetryApi(url: 'https://example.test/batches');
    final batch = {
      'patient_id': 'fixture-patient',
      'b_number': 1,
      'batch_timestamp': '2026-11-21T18:00:00Z',
      'batch_interval_in_seconds': 60,
      'hr': <int>[],
      'temperature': [33.02, 33.08, 90.0, double.nan],
      'steps': 0,
    };
    final payload = api.payloadFor(batch);
    expect(payload['temperature'], 33.1);
    expect(payload['steps'], 0);
    expect(payload.containsKey('hr'), isFalse);
    final exact = api.payloadFor({
      ...batch,
      'temperature': [36.6, 36.6, 36.6],
    });
    expect(exact['temperature'], 36.6);
    final missing = api.payloadFor({...batch, 'temperature': <double>[]});
    expect(missing.containsKey('temperature'), isFalse);
  });
}
