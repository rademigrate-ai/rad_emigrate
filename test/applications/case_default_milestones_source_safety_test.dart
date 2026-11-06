import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/applications/domain/entities/application_status.dart';
import 'package:rad_emigrate/features/applications/domain/entities/visa_application.dart';
import 'package:rad_emigrate/features/applications/presentation/providers/case_tracker_controller.dart';

void main() {
  test('initial case milestones make no unverified immigration claims', () {
    final app = VisaApplication(
      id: 'synthetic-app',
      title: 'Synthetic case',
      programName: 'Unverified program',
      country: 'Unverified destination',
      status: ApplicationStatus.draft,
      updatedAt: DateTime.utc(2026, 11, 5),
    );
    final items = defaultMilestoneItems(app, clock: DateTime.utc(2026, 11, 5));
    expect(items, isNotEmpty);
    expect(items.every((item) => item.dueDate == null), isTrue);
    expect(items.every((item) => item.completedAt == null), isTrue);
    expect(items.every((item) => item.status.name == 'notStarted'), isTrue);
    final descriptions = items
        .map((item) => '${item.title} ${item.description ?? ''}')
        .join(' ')
        .toLowerCase();
    for (final unsupported in <String>[
      '6 months',
      'ielts',
      'ec a',
      'bank statement',
      'biometrics',
      'appointment',
    ]) {
      expect(descriptions, isNot(contains(unsupported)));
    }
    expect(descriptions, contains('official'));
  });
}
