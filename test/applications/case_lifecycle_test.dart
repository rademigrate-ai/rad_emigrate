import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/applications/domain/case_lifecycle.dart';
import 'package:rad_emigrate/features/applications/domain/entities/application_status.dart';
import 'package:rad_emigrate/features/applications/domain/entities/case_checklist.dart';
import 'package:rad_emigrate/features/applications/domain/entities/visa_application.dart';

void main() {
  const service = CaseLifecycleService();
  final now = DateTime.utc(2026, 10, 18, 12);

  ImmigrationCase sampleCase({
    String owner = 'user-a',
    ApplicationStatus status = ApplicationStatus.draft,
    List<CaseChecklistItem>? items,
  }) {
    final app = VisaApplication(
      id: 'case-1',
      userId: owner,
      title: 'Canada study',
      programName: 'Study Permit',
      country: 'CA',
      status: status,
      updatedAt: now,
      createdAt: now,
    );
    final checklist = CaseChecklist(
      caseId: 'case-1',
      applicationStatus: status,
      items:
          items ??
          [
            CaseChecklistItem(
              id: 'doc-1',
              title: 'Passport',
              dueDate: now.add(const Duration(days: 2)),
            ),
            const CaseChecklistItem(id: 'doc-2', title: 'Transcript'),
          ],
    );
    return ImmigrationCase(application: app, checklist: checklist);
  }

  group('ownership isolation', () {
    test('assertOwnership denies other user', () {
      final c = sampleCase(owner: 'user-a');
      expect(
        () => service.assertOwnership(c, 'user-b'),
        throwsA(
          isA<CaseLifecycleException>().having(
            (e) => e.code,
            'code',
            'ownership_denied',
          ),
        ),
      );
    });

    test('filterOwned returns only actor cases', () {
      final all = [sampleCase(owner: 'user-a'), sampleCase(owner: 'user-b')];
      // second case needs distinct id for realism
      final owned = service.filterOwned(all, 'user-a');
      expect(owned.length, 1);
      expect(owned.first.ownerUserId, 'user-a');
    });

    test('missing owner throws', () {
      final app = VisaApplication(
        id: 'x',
        title: 't',
        programName: 'p',
        country: 'CA',
        status: ApplicationStatus.draft,
        updatedAt: now,
      );
      final c = ImmigrationCase(
        application: app,
        checklist: const CaseChecklist(caseId: 'x', items: []),
      );
      expect(
        () => service.assertOwnership(c, 'user-a'),
        throwsA(
          isA<CaseLifecycleException>().having(
            (e) => e.code,
            'code',
            'missing_owner',
          ),
        ),
      );
    });
  });

  group('application status transitions', () {
    test('draft → submitted succeeds', () {
      final c = sampleCase();
      final next = service.transitionApplicationStatus(
        case_: c,
        actorUserId: 'user-a',
        next: ApplicationStatus.submitted,
        nowUtc: now,
        historyId: 'h1',
      );
      expect(next.application.status, ApplicationStatus.submitted);
      expect(next.history.last.action, contains('draft->submitted'));
    });

    test('completed → submitted is invalid', () {
      final c = sampleCase(status: ApplicationStatus.completed);
      expect(
        () => service.transitionApplicationStatus(
          case_: c,
          actorUserId: 'user-a',
          next: ApplicationStatus.submitted,
          nowUtc: now,
        ),
        throwsA(
          isA<CaseLifecycleException>().having(
            (e) => e.code,
            'code',
            'invalid_status_transition',
          ),
        ),
      );
    });

    test('rejected → draft reopen allowed', () {
      final c = sampleCase(status: ApplicationStatus.rejected);
      final next = service.transitionApplicationStatus(
        case_: c,
        actorUserId: 'user-a',
        next: ApplicationStatus.draft,
        nowUtc: now,
      );
      expect(next.application.status, ApplicationStatus.draft);
    });
  });

  group('checklist transitions and duplicates', () {
    test('complete item once', () {
      final c = sampleCase();
      final next = service.completeChecklistItemOnce(
        case_: c,
        actorUserId: 'user-a',
        itemId: 'doc-1',
        nowUtc: now,
      );
      expect(
        next.checklist.items.firstWhere((e) => e.id == 'doc-1').status,
        ChecklistItemStatus.completed,
      );
    });

    test('duplicate complete throws', () {
      var c = sampleCase();
      c = service.completeChecklistItemOnce(
        case_: c,
        actorUserId: 'user-a',
        itemId: 'doc-1',
        nowUtc: now,
      );
      expect(
        () => service.completeChecklistItemOnce(
          case_: c,
          actorUserId: 'user-a',
          itemId: 'doc-1',
          nowUtc: now,
        ),
        throwsA(
          isA<CaseLifecycleException>().having(
            (e) => e.code,
            'code',
            'duplicate_action',
          ),
        ),
      );
    });

    test('invalid checklist transition blocked→completed denied', () {
      final c = sampleCase(
        items: const [
          CaseChecklistItem(
            id: 'doc-1',
            title: 'Passport',
            status: ChecklistItemStatus.blocked,
          ),
        ],
      );
      expect(
        () => service.transitionChecklistItem(
          case_: c,
          actorUserId: 'user-a',
          itemId: 'doc-1',
          next: ChecklistItemStatus.completed,
          nowUtc: now,
        ),
        throwsA(
          isA<CaseLifecycleException>().having(
            (e) => e.code,
            'code',
            'invalid_checklist_transition',
          ),
        ),
      );
    });

    test('reopen completed → inProgress allowed', () {
      final c = sampleCase(
        items: [
          CaseChecklistItem(
            id: 'doc-1',
            title: 'Passport',
            status: ChecklistItemStatus.completed,
            completedAt: now,
          ),
        ],
      );
      final next = service.transitionChecklistItem(
        case_: c,
        actorUserId: 'user-a',
        itemId: 'doc-1',
        next: ChecklistItemStatus.inProgress,
        nowUtc: now,
      );
      expect(next.checklist.items.first.status, ChecklistItemStatus.inProgress);
    });
  });

  group('reminders and overdue', () {
    test('pendingReminders includes past due open items', () {
      final c = sampleCase(
        items: [
          CaseChecklistItem(
            id: 'doc-1',
            title: 'Passport',
            dueDate: now.subtract(const Duration(days: 1)),
          ),
        ],
      );
      final reminders = service.pendingReminders(c, nowUtc: now);
      expect(reminders.length, 1);
      expect(reminders.first.isPastDue(now), isTrue);
    });

    test('completed items excluded from reminders', () {
      final c = sampleCase(
        items: [
          CaseChecklistItem(
            id: 'doc-1',
            title: 'Passport',
            status: ChecklistItemStatus.completed,
            dueDate: now.subtract(const Duration(days: 1)),
            completedAt: now,
          ),
        ],
      );
      expect(service.pendingReminders(c, nowUtc: now), isEmpty);
    });
  });
}
