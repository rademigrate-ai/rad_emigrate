import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/applications/domain/entities/application_status.dart';
import 'package:rad_emigrate/features/applications/domain/entities/visa_application.dart';

void main() {
  test('status transition via copyWith', () {
    final draft = VisaApplication(
      id: 'a1',
      title: 'Study',
      programName: 'Canada Study',
      country: 'Canada',
      status: ApplicationStatus.draft,
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final submitted = draft.copyWith(
      status: ApplicationStatus.submitted,
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    expect(submitted.status, ApplicationStatus.submitted);
    expect(submitted.id, draft.id);
    expect(submitted.status.label, 'Submitted');
  });
}
