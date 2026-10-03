import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/applications/domain/entities/application_status.dart';
import 'package:rad_emigrate/features/applications/domain/entities/visa_application.dart';

void main() {
  group('ApplicationStatus acceptance', () {
    test('every status has a non-empty human label', () {
      for (final status in ApplicationStatus.values) {
        expect(status.label, isNotEmpty, reason: status.name);
      }
    });

    test('fromString maps known names and defaults unknown to draft', () {
      expect(
        ApplicationStatusX.fromString('submitted'),
        ApplicationStatus.submitted,
      );
      expect(
        ApplicationStatusX.fromString('not_a_real_status'),
        ApplicationStatus.draft,
      );
    });

    test('owner update via copyWith retains identity fields', () {
      final original = VisaApplication(
        id: 'app-1',
        userId: 'user-a',
        title: 'Study Permit',
        programName: 'Canada Study',
        country: 'CA',
        status: ApplicationStatus.draft,
        updatedAt: DateTime.utc(2026, 3, 1),
      );
      final updated = original.copyWith(
        status: ApplicationStatus.submitted,
        updatedAt: DateTime.utc(2026, 3, 2),
      );
      expect(updated.id, original.id);
      expect(updated.userId, 'user-a');
      expect(updated.status, ApplicationStatus.submitted);
      expect(updated.status.label, 'Submitted');
    });

    test('serialization preserves owner and status', () {
      final app = VisaApplication(
        id: 'app-2',
        userId: 'user-a',
        title: 'Work',
        programName: 'PGWP',
        country: 'CA',
        status: ApplicationStatus.reviewing,
        updatedAt: DateTime.utc(2026, 4, 1),
      );
      final restored = VisaApplication.fromJson(app.toJson());
      expect(restored.userId, 'user-a');
      expect(restored.status, ApplicationStatus.reviewing);
    });
  });
}
