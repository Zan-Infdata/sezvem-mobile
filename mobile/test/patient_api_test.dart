import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/sync/patient_api.dart';

void main() {
  test('creates a patient on the telemetry host and reads its ID', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests =
        <({String method, String path, String? mimeType, Object? body})>[];
    var status = HttpStatus.created;
    Object response = {'patient_id': 'p-abc01234', 'name': 'IXLand patient'};
    server.listen((request) async {
      requests.add((
        method: request.method,
        path: request.uri.path,
        mimeType: request.headers.contentType?.mimeType,
        body: jsonDecode(await utf8.decoder.bind(request).join()),
      ));
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    });

    final api = PatientApi(
      batchUrl: 'http://127.0.0.1:${server.port}/api/batches',
    );
    expect(await api.createPatient(), 'p-abc01234');
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/patients');
    expect(request.mimeType, 'application/json');
    expect(request.body, {'name': 'IXLand patient'});

    status = HttpStatus.unprocessableEntity;
    response = {
      'error': {'code': 'validation_error'},
    };
    await expectLater(
      api.createPatient(),
      throwsA(isA<PatientCreationException>()),
    );

    status = HttpStatus.created;
    response = {'patient_id': 'invalid id'};
    await expectLater(
      api.createPatient(),
      throwsA(isA<PatientCreationException>()),
    );
    expect(requests, hasLength(3));
  });
}
