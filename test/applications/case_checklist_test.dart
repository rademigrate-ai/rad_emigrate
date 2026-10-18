import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/applications/domain/entities/application_status.dart';
import 'package:rad_emigrate/features/applications/domain/entities/case_checklist.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 10, 18, 12);

  group('CaseChecklistItem transitions', () {
    test('markCompleted sets status and completedAt', () {
      const item = CaseChecklistItem(id: '1', title: 'Passport');
      final done = item.markCompleted(at: fixedNow);
      expect(done.status, ChecklistItemStatus.completed);
      expect(done.completedAt, fixedNow);
      expect(done.status.countsAsDone, isTrue);
    });

    test('markSkipped counts as done', () {
      const item = CaseChecklistItem(id: '1', title: 'Optional form');
      final skipped = item.markSkipped(at: fixedNow);
      expect(skipped.status, ChecklistItemStatus.skipped);
      expect(skipped.status.countsAsDone, isTrue);
    });

    test('reset clears completedAt', () {
      final done = const CaseChecklistItem(
        id: '1',
        title: 'Doc',
      ).markCompleted(at: fixedNow);
      final reset = done.reset();
      expect(reset.status, ChecklistItemStatus.notStarted);
      expect(reset.completedAt, isNull);
    });

    test('isOverdue only for open items past dueDate', () {
      final overdue = CaseChecklistItem(
        id: '1',
        title: 'Upload',
        dueDate: fixedNow.subtract(const Duration(days: 1)),
      );
      expect(overdue.isOverdue(fixedNow), isTrue);

      final done = overdue.markCompleted(at: fixedNow);
      expect(done.isOverdue(fixedNow), isFalse);

      const noDue = CaseChecklistItem(id: '2', title: 'No due');
      expect(noDue.isOverdue(fixedNow), isFalse);
    });
  });

  group('CaseChecklist progress', () {
    test('empty checklist has zero progress', () {
      const checklist = CaseChecklist(caseId: 'c1', items: []);
      final p = checklist.progress(now: fixedNow);
      expect(p.total, 0);
      expect(p.ratio, 0);
      expect(p.percent, 0);
      expect(p.isEmpty, isTrue);
      expect(p.isComplete, isFalse);
    });

    test('mixed statuses compute ratio and overdue', () {
      final items = [
        const CaseChecklistItem(
          id: 'a',
          title: 'A',
          status: ChecklistItemStatus.completed,
          sortOrder: 1,
        ),
        const CaseChecklistItem(
          id: 'b',
          title: 'B',
          status: ChecklistItemStatus.skipped,
          sortOrder: 2,
        ),
        CaseChecklistItem(
          id: 'c',
          title: 'C',
          status: ChecklistItemStatus.inProgress,
          dueDate: fixedNow.subtract(const Duration(hours: 2)),
          sortOrder: 3,
        ),
        const CaseChecklistItem(
          id: 'd',
          title: 'D',
          status: ChecklistItemStatus.blocked,
          sortOrder: 4,
        ),
        const CaseChecklistItem(
          id: 'e',
          title: 'E',
          status: ChecklistItemStatus.notStarted,
          sortOrder: 5,
        ),
      ];
      final checklist = CaseChecklist(
        caseId: 'c1',
        items: items,
        applicationStatus: ApplicationStatus.documentsRequired,
      );
      final p = checklist.progress(now: fixedNow);
      expect(p.total, 5);
      expect(p.completed, 2); // completed + skipped
      expect(p.inProgress, 1);
      expect(p.blocked, 1);
      expect(p.overdue, 1);
      expect(p.percent, 40);
      expect(p.isComplete, isFalse);
      expect(checklist.overdueItems(now: fixedNow).map((e) => e.id), ['c']);
    });

    test('updateItem replaces by id', () {
      const checklist = CaseChecklist(
        caseId: 'c1',
        items: [
          CaseChecklistItem(id: 'a', title: 'A'),
          CaseChecklistItem(id: 'b', title: 'B'),
        ],
      );
      final updated = checklist.updateItem(
        const CaseChecklistItem(
          id: 'b',
          title: 'B',
          status: ChecklistItemStatus.completed,
        ),
      );
      expect(updated.items[1].status, ChecklistItemStatus.completed);
      expect(updated.items[0].status, ChecklistItemStatus.notStarted);
    });

    test('sortedByOrder respects sortOrder', () {
      const checklist = CaseChecklist(
        caseId: 'c1',
        items: [
          CaseChecklistItem(id: 'z', title: 'Z', sortOrder: 20),
          CaseChecklistItem(id: 'a', title: 'A', sortOrder: 1),
        ],
      );
      final sorted = checklist.sortedByOrder();
      expect(sorted.map((e) => e.id).toList(), ['a', 'z']);
    });

    test('toJson / fromJson round-trip', () {
      final original = CaseChecklist(
        caseId: 'case-9',
        applicationStatus: ApplicationStatus.reviewing,
        items: [
          CaseChecklistItem(
            id: 'i1',
            title: 'Passport copy',
            status: ChecklistItemStatus.inProgress,
            dueDate: fixedNow,
            sortOrder: 0,
          ),
        ],
      );
      final restored = CaseChecklist.fromJson(original.toJson());
      expect(restored.caseId, original.caseId);
      expect(restored.applicationStatus, ApplicationStatus.reviewing);
      expect(restored.items.length, 1);
      expect(restored.items.first.id, 'i1');
      expect(restored.items.first.status, ChecklistItemStatus.inProgress);
    });

    test('all completed isComplete', () {
      const checklist = CaseChecklist(
        caseId: 'c1',
        items: [
          CaseChecklistItem(
            id: '1',
            title: 'One',
            status: ChecklistItemStatus.completed,
          ),
          CaseChecklistItem(
            id: '2',
            title: 'Two',
            status: ChecklistItemStatus.skipped,
          ),
        ],
      );
      final p = checklist.progress(now: fixedNow);
      expect(p.isComplete, isTrue);
      expect(p.percent, 100);
    });
  });
}
