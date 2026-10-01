import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/applications/domain/entities/application_status.dart';
import 'package:rad_emigrate/features/applications/domain/entities/visa_application.dart';

void main() {
  group('VisaApplication', () {
    test('serialization round-trip', () {
      final app = VisaApplication(
        id: 'app-1',
        title: 'Study Permit',
        programName: 'Canada Study',
        country: 'Canada',
        status: ApplicationStatus.submitted,
        updatedAt: DateTime.utc(2026, 9, 1),
        notes: 'Pending',
      );
      final restored = VisaApplication.fromJson(app.toJson());
      expect(restored.id, app.id);
      expect(restored.status, ApplicationStatus.submitted);
      expect(restored.programName, app.programName);
      expect(restored, app);
    });

    test('status labels', () {
      expect(ApplicationStatus.draft.label, 'Draft');
      expect(ApplicationStatus.documentsRequired.label, 'Documents Required');
      expect(ApplicationStatus.completed.label, 'Completed');
    });
  });
}
