import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/companion/companion_overlay.dart';
import 'package:ixland_mobile/settings/patient_settings.dart';
import 'package:ixland_mobile/settings/settings_screen.dart';

void main() {
  testWidgets('edits, creates, and restores the saved patient ID', (
    tester,
  ) async {
    const patientChannel = MethodChannel('ixland/patient_settings');
    const companionChannel = MethodChannel('ixland/companion');
    final messenger = tester.binding.defaultBinaryMessenger;
    String? persistedId;
    messenger.setMockMethodCallHandler(patientChannel, (call) async {
      switch (call.method) {
        case 'getPatientId':
          return persistedId;
        case 'setPatientId':
          persistedId = call.arguments as String;
          return null;
        default:
          throw MissingPluginException();
      }
    });
    messenger.setMockMethodCallHandler(companionChannel, (call) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(patientChannel, null);
      messenger.setMockMethodCallHandler(companionChannel, null);
    });

    Future<void> openSettings(PatientSettings settings) async {
      await settings.load();
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            key: ObjectKey(settings),
            companion: const AndroidCompanionOverlay(),
            patientSettings: settings,
          ),
        ),
      );
      await tester.pump();
    }

    final field = find.byType(TextField);
    String displayedId() => tester.widget<TextField>(field).controller!.text;

    final settings = PatientSettings(defaultId: 'build-id');
    await openSettings(settings);
    expect(displayedId(), 'build-id');

    final save = find.text('Save patient ID');
    await tester.enterText(field, 'invalid patient');
    await tester.tap(save);
    await tester.pump();
    expect(find.textContaining('1–128'), findsOneWidget);
    expect(persistedId, isNull);
    expect(settings.patientId, 'build-id');

    await tester.enterText(field, '  edited-id  ');
    await tester.tap(save);
    await tester.pump();
    expect(displayedId(), 'edited-id');
    expect(persistedId, 'edited-id');
    expect(settings.patientId, 'edited-id');

    await tester.tap(find.text('Create patient'));
    await tester.pump();
    final created = displayedId();
    expect(created, matches(RegExp(r'^test-[a-f0-9]{32}$')));
    expect(persistedId, created);
    expect(settings.patientId, created);

    final restarted = PatientSettings(defaultId: 'build-id');
    await openSettings(restarted);
    expect(displayedId(), created);
    expect(restarted.patientId, created);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
