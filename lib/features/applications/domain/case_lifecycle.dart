// Case lifecycle operations for RAD Emigrate.
// Ownership isolation, valid transitions, deterministic due-date handling.
// Does not claim notification delivery.

import 'entities/application_status.dart';
import 'entities/case_checklist.dart';
import 'entities/visa_application.dart';

/// Local reminder metadata only — no delivery side effects.
class CaseReminderMeta {
  const CaseReminderMeta({
    required this.itemId,
    required this.dueDateUtc,
    this.title,
    this.leadTime = const Duration(days: 1),
  });

  final String itemId;
  final DateTime dueDateUtc;
  final String? title;
  final Duration leadTime;

  DateTime get remindAtUtc => dueDateUtc.subtract(leadTime);

  bool isDue(DateTime nowUtc) =>
      !nowUtc.isBefore(remindAtUtc) && nowUtc.isBefore(dueDateUtc);

  bool isPastDue(DateTime nowUtc) => !nowUtc.isBefore(dueDateUtc);

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'dueDateUtc': dueDateUtc.toIso8601String(),
    'title': title,
    'leadTimeHours': leadTime.inHours,
  };
}

/// Append-only case history entry.
class CaseHistoryEntry {
  const CaseHistoryEntry({
    required this.id,
    required this.caseId,
    required this.atUtc,
    required this.action,
    this.actorUserId,
    this.detail,
  });

  final String id;
  final String caseId;
  final DateTime atUtc;
  final String action;
  final String? actorUserId;
  final String? detail;

  Map<String, dynamic> toJson() => {
    'id': id,
    'caseId': caseId,
    'atUtc': atUtc.toIso8601String(),
    'action': action,
    'actorUserId': actorUserId,
    'detail': detail,
  };

  factory CaseHistoryEntry.fromJson(Map<String, dynamic> json) {
    return CaseHistoryEntry(
      id: json['id'] as String? ?? '',
      caseId: json['caseId'] as String? ?? '',
      atUtc:
          DateTime.tryParse(json['atUtc'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      action: json['action'] as String? ?? '',
      actorUserId: json['actorUserId'] as String?,
      detail: json['detail'] as String?,
    );
  }
}

/// Full case aggregate: application + checklist + history.
class ImmigrationCase {
  const ImmigrationCase({
    required this.application,
    required this.checklist,
    this.history = const [],
  });

  final VisaApplication application;
  final CaseChecklist checklist;
  final List<CaseHistoryEntry> history;

  String get caseId => application.id;
  String? get ownerUserId => application.userId;

  ImmigrationCase copyWith({
    VisaApplication? application,
    CaseChecklist? checklist,
    List<CaseHistoryEntry>? history,
  }) {
    return ImmigrationCase(
      application: application ?? this.application,
      checklist: checklist ?? this.checklist,
      history: history ?? this.history,
    );
  }
}

/// Domain errors for case lifecycle (not network exceptions).
class CaseLifecycleException implements Exception {
  CaseLifecycleException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'CaseLifecycleException($code): $message';
}

/// Allowed application status transitions (deterministic matrix).
class ApplicationStatusTransitions {
  static const Map<ApplicationStatus, Set<ApplicationStatus>> allowed = {
    ApplicationStatus.draft: {
      ApplicationStatus.submitted,
      ApplicationStatus.draft,
    },
    ApplicationStatus.submitted: {
      ApplicationStatus.reviewing,
      ApplicationStatus.documentsRequired,
      ApplicationStatus.rejected,
    },
    ApplicationStatus.reviewing: {
      ApplicationStatus.documentsRequired,
      ApplicationStatus.approved,
      ApplicationStatus.rejected,
    },
    ApplicationStatus.documentsRequired: {
      ApplicationStatus.submitted,
      ApplicationStatus.reviewing,
      ApplicationStatus.rejected,
    },
    ApplicationStatus.approved: {ApplicationStatus.completed},
    ApplicationStatus.rejected: {
      ApplicationStatus.draft, // reopen as new draft path
    },
    ApplicationStatus.completed: {},
  };

  static bool canTransition(ApplicationStatus from, ApplicationStatus to) {
    if (from == to) return true;
    return allowed[from]?.contains(to) ?? false;
  }
}

/// Checklist item transition rules.
class ChecklistTransitionRules {
  static bool canTransition(ChecklistItemStatus from, ChecklistItemStatus to) {
    if (from == to) return true;
    switch (from) {
      case ChecklistItemStatus.notStarted:
        return to == ChecklistItemStatus.inProgress ||
            to == ChecklistItemStatus.completed ||
            to == ChecklistItemStatus.skipped ||
            to == ChecklistItemStatus.blocked;
      case ChecklistItemStatus.inProgress:
        return to == ChecklistItemStatus.completed ||
            to == ChecklistItemStatus.blocked ||
            to == ChecklistItemStatus.skipped ||
            to == ChecklistItemStatus.notStarted;
      case ChecklistItemStatus.blocked:
        return to == ChecklistItemStatus.inProgress ||
            to == ChecklistItemStatus.notStarted ||
            to == ChecklistItemStatus.skipped;
      case ChecklistItemStatus.completed:
        // Reopen allowed
        return to == ChecklistItemStatus.inProgress ||
            to == ChecklistItemStatus.notStarted;
      case ChecklistItemStatus.skipped:
        return to == ChecklistItemStatus.notStarted ||
            to == ChecklistItemStatus.inProgress;
    }
  }
}

/// Pure case lifecycle service. Callers supply identity; service enforces isolation.
class CaseLifecycleService {
  const CaseLifecycleService();

  /// Ensures [actorUserId] owns [case_]. Throws on mismatch or missing owner.
  void assertOwnership(ImmigrationCase case_, String actorUserId) {
    final owner = case_.ownerUserId;
    if (owner == null || owner.isEmpty) {
      throw CaseLifecycleException(
        'missing_owner',
        'Case has no owner userId; cannot authorize access.',
      );
    }
    if (owner != actorUserId) {
      throw CaseLifecycleException(
        'ownership_denied',
        'Actor is not the case owner.',
      );
    }
  }

  /// Filters a list to only the actor's cases (ownership isolation helper).
  List<ImmigrationCase> filterOwned(
    List<ImmigrationCase> all,
    String actorUserId,
  ) {
    return all
        .where((c) => c.ownerUserId != null && c.ownerUserId == actorUserId)
        .toList(growable: false);
  }

  ImmigrationCase transitionApplicationStatus({
    required ImmigrationCase case_,
    required String actorUserId,
    required ApplicationStatus next,
    DateTime? nowUtc,
    String? historyId,
  }) {
    assertOwnership(case_, actorUserId);
    final current = case_.application.status;
    if (!ApplicationStatusTransitions.canTransition(current, next)) {
      throw CaseLifecycleException(
        'invalid_status_transition',
        'Cannot transition application from ${current.name} to ${next.name}.',
      );
    }
    final clock = nowUtc ?? DateTime.now().toUtc();
    final updatedApp = case_.application.copyWith(
      status: next,
      updatedAt: clock,
    );
    final entry = CaseHistoryEntry(
      id: historyId ?? 'h_${clock.microsecondsSinceEpoch}',
      caseId: case_.caseId,
      atUtc: clock,
      action: 'application_status:${current.name}->${next.name}',
      actorUserId: actorUserId,
    );
    return case_.copyWith(
      application: updatedApp,
      checklist: case_.checklist.copyWith(applicationStatus: next),
      history: [...case_.history, entry],
    );
  }

  ImmigrationCase transitionChecklistItem({
    required ImmigrationCase case_,
    required String actorUserId,
    required String itemId,
    required ChecklistItemStatus next,
    DateTime? nowUtc,
    String? historyId,
  }) {
    assertOwnership(case_, actorUserId);
    final idx = case_.checklist.items.indexWhere((e) => e.id == itemId);
    if (idx < 0) {
      throw CaseLifecycleException(
        'item_not_found',
        'Checklist item $itemId not found on case.',
      );
    }
    final item = case_.checklist.items[idx];
    if (!ChecklistTransitionRules.canTransition(item.status, next)) {
      throw CaseLifecycleException(
        'invalid_checklist_transition',
        'Cannot transition checklist item from ${item.status.name} to ${next.name}.',
      );
    }
    final clock = nowUtc ?? DateTime.now().toUtc();
    CaseChecklistItem updated;
    switch (next) {
      case ChecklistItemStatus.completed:
        updated = item.markCompleted(at: clock);
      case ChecklistItemStatus.skipped:
        updated = item.markSkipped(at: clock);
      case ChecklistItemStatus.inProgress:
        updated = item.markInProgress();
      case ChecklistItemStatus.blocked:
        updated = item.markBlocked();
      case ChecklistItemStatus.notStarted:
        updated = item.reset();
    }
    final nextChecklist = case_.checklist.updateItem(updated);
    final entry = CaseHistoryEntry(
      id: historyId ?? 'h_${clock.microsecondsSinceEpoch}',
      caseId: case_.caseId,
      atUtc: clock,
      action: 'checklist:${item.id}:${item.status.name}->${next.name}',
      actorUserId: actorUserId,
    );
    return case_.copyWith(
      checklist: nextChecklist,
      history: [...case_.history, entry],
    );
  }

  /// Prevents duplicate complete/skip actions on an already-done item.
  ImmigrationCase completeChecklistItemOnce({
    required ImmigrationCase case_,
    required String actorUserId,
    required String itemId,
    DateTime? nowUtc,
  }) {
    assertOwnership(case_, actorUserId);
    CaseChecklistItem? item;
    for (final e in case_.checklist.items) {
      if (e.id == itemId) {
        item = e;
        break;
      }
    }
    if (item == null) {
      throw CaseLifecycleException(
        'item_not_found',
        'Checklist item $itemId not found on case.',
      );
    }
    if (item.status.countsAsDone) {
      throw CaseLifecycleException(
        'duplicate_action',
        'Checklist item $itemId is already ${item.status.name}.',
      );
    }
    return transitionChecklistItem(
      case_: case_,
      actorUserId: actorUserId,
      itemId: itemId,
      next: ChecklistItemStatus.completed,
      nowUtc: nowUtc,
    );
  }

  /// Builds local reminder metadata for open items with due dates.
  List<CaseReminderMeta> pendingReminders(
    ImmigrationCase case_, {
    DateTime? nowUtc,
    Duration leadTime = const Duration(days: 1),
  }) {
    final clock = nowUtc ?? DateTime.now().toUtc();
    final out = <CaseReminderMeta>[];
    for (final item in case_.checklist.items) {
      if (item.dueDate == null) continue;
      if (item.status.countsAsDone) continue;
      final due = item.dueDate!.toUtc();
      final meta = CaseReminderMeta(
        itemId: item.id,
        dueDateUtc: due,
        title: item.title,
        leadTime: leadTime,
      );
      if (meta.isDue(clock) || meta.isPastDue(clock)) {
        out.add(meta);
      }
    }
    return out;
  }

  CaseChecklistProgress progress(ImmigrationCase case_, {DateTime? nowUtc}) {
    return case_.checklist.progress(now: nowUtc ?? DateTime.now().toUtc());
  }
}
