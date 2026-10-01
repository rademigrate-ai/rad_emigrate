import '../domain/entities/application_entities.dart';

final mockApplications = [
  Application(
    id: 'app-001',
    title: 'Study Permit Application',
    programName: 'Canada Study Permit',
    country: 'Canada',
    status: ApplicationStatus.underReview,
    updatedAt: DateTime(2026, 9, 20),
    notes: 'Documents submitted. Awaiting IRCC response.',
  ),
  Application(
    id: 'app-002',
    title: 'Student Visa Draft',
    programName: 'Australia Student Visa (500)',
    country: 'Australia',
    status: ApplicationStatus.draft,
    updatedAt: DateTime(2026, 9, 28),
    notes: 'GTE statement pending.',
  ),
  Application(
    id: 'app-003',
    title: 'Job Seeker',
    programName: 'Germany Job Seeker Visa',
    country: 'Germany',
    status: ApplicationStatus.submitted,
    updatedAt: DateTime(2026, 9, 15),
  ),
];
