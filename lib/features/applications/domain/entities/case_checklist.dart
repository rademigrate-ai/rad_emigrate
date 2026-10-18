// Case checklist and milestone domain models for RAD Emigrate.
// Pure domain logic. Does not claim notification delivery or legal outcomes.

import 'application_status.dart';

/// Lifecycle state of a single checklist item.
enum ChecklistItemStatus { notStarted, inProgress, completed, blocked, skipped }

extension ChecklistItemStatusX on ChecklistItemStatus {
  String get key => name;

  static ChecklistItemStatus fromString(String? value) {
    if (value == null || value.isEmpty) return ChecklistItemStatus.notStarted;
    return ChecklistItemStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ChecklistItemStatus.notStarted,
    );
  }

  bool get countsAsDone =>
      this == ChecklistItemStatus.completed ||
      this == ChecklistItemStatus.skipped;
}

/// Immutable checklist item (document, form, appointment, etc.).
class CaseChecklistItem {
  const CaseChecklistItem({
    required this.id,
    required this.title,
    this.description,
    this.status = ChecklistItemStatus.notStarted,
    this.dueDate,
    this.completedAt,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final String? description;
  final ChecklistItemStatus status;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final int sortOrder;

  CaseChecklistItem copyWith({
    String? id,
    String? title,
    String? description,
    ChecklistItemStatus? status,
    DateTime? dueDate,
    DateTime? completedAt,
    int? sortOrder,
    bool clearDueDate = false,
    bool clearCompletedAt = false,
  }) {
    return CaseChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Transition helpers (pure; caller decides persistence).
  CaseChecklistItem markCompleted({DateTime? at}) {
    return copyWith(
      status: ChecklistItemStatus.completed,
      completedAt: at ?? DateTime.now().toUtc(),
    );
  }

  CaseChecklistItem markInProgress() {
    return copyWith(
      status: ChecklistItemStatus.inProgress,
      clearCompletedAt: true,
    );
  }

  CaseChecklistItem markBlocked() {
    return copyWith(
      status: ChecklistItemStatus.blocked,
      clearCompletedAt: true,
    );
  }

  CaseChecklistItem markSkipped({DateTime? at}) {
    return copyWith(
      status: ChecklistItemStatus.skipped,
      completedAt: at ?? DateTime.now().toUtc(),
    );
  }

  CaseChecklistItem reset() {
    return copyWith(
      status: ChecklistItemStatus.notStarted,
      clearCompletedAt: true,
    );
  }

  bool isOverdue(DateTime now) {
    if (dueDate == null) return false;
    if (status.countsAsDone) return false;
    return dueDate!.isBefore(now);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'status': status.name,
    'dueDate': dueDate?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'sortOrder': sortOrder,
  };

  factory CaseChecklistItem.fromJson(Map<String, dynamic> json) {
    return CaseChecklistItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: ChecklistItemStatusX.fromString(json['status'] as String?),
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaseChecklistItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          status == other.status &&
          dueDate == other.dueDate &&
          completedAt == other.completedAt &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode =>
      Object.hash(id, title, status, dueDate, completedAt, sortOrder);
}

/// Aggregated progress for a case checklist.
class CaseChecklistProgress {
  const CaseChecklistProgress({
    required this.total,
    required this.completed,
    required this.inProgress,
    required this.blocked,
    required this.overdue,
    required this.ratio,
  });

  final int total;
  final int completed;
  final int inProgress;
  final int blocked;
  final int overdue;

  /// Completed + skipped over total, in [0.0, 1.0]. Empty checklist → 0.0.
  final double ratio;

  int get percent => (ratio * 100).round();

  bool get isEmpty => total == 0;
  bool get isComplete => total > 0 && completed == total;
}

/// Case + checklist aggregate (links to existing VisaApplication status).
class CaseChecklist {
  const CaseChecklist({
    required this.caseId,
    required this.items,
    this.applicationStatus = ApplicationStatus.draft,
  });

  final String caseId;
  final List<CaseChecklistItem> items;
  final ApplicationStatus applicationStatus;

  CaseChecklist copyWith({
    String? caseId,
    List<CaseChecklistItem>? items,
    ApplicationStatus? applicationStatus,
  }) {
    return CaseChecklist(
      caseId: caseId ?? this.caseId,
      items: items ?? this.items,
      applicationStatus: applicationStatus ?? this.applicationStatus,
    );
  }

  /// Replace one item by id; returns same instance if id not found.
  CaseChecklist updateItem(CaseChecklistItem updated) {
    final idx = items.indexWhere((e) => e.id == updated.id);
    if (idx < 0) return this;
    final next = List<CaseChecklistItem>.from(items);
    next[idx] = updated;
    return copyWith(items: next);
  }

  CaseChecklistProgress progress({DateTime? now}) {
    final clock = now ?? DateTime.now().toUtc();
    if (items.isEmpty) {
      return const CaseChecklistProgress(
        total: 0,
        completed: 0,
        inProgress: 0,
        blocked: 0,
        overdue: 0,
        ratio: 0,
      );
    }
    var completed = 0;
    var inProgress = 0;
    var blocked = 0;
    var overdue = 0;
    for (final item in items) {
      switch (item.status) {
        case ChecklistItemStatus.completed:
        case ChecklistItemStatus.skipped:
          completed++;
        case ChecklistItemStatus.inProgress:
          inProgress++;
        case ChecklistItemStatus.blocked:
          blocked++;
        case ChecklistItemStatus.notStarted:
          break;
      }
      if (item.isOverdue(clock)) overdue++;
    }
    return CaseChecklistProgress(
      total: items.length,
      completed: completed,
      inProgress: inProgress,
      blocked: blocked,
      overdue: overdue,
      ratio: completed / items.length,
    );
  }

  List<CaseChecklistItem> overdueItems({DateTime? now}) {
    final clock = now ?? DateTime.now().toUtc();
    return items.where((e) => e.isOverdue(clock)).toList();
  }

  List<CaseChecklistItem> sortedByOrder() {
    final copy = List<CaseChecklistItem>.from(items);
    copy.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return copy;
  }

  Map<String, dynamic> toJson() => {
    'caseId': caseId,
    'applicationStatus': applicationStatus.name,
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory CaseChecklist.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <CaseChecklistItem>[];
    if (rawItems is List) {
      for (final row in rawItems) {
        if (row is Map<String, dynamic>) {
          items.add(CaseChecklistItem.fromJson(row));
        } else if (row is Map) {
          items.add(CaseChecklistItem.fromJson(Map<String, dynamic>.from(row)));
        }
      }
    }
    return CaseChecklist(
      caseId: json['caseId'] as String? ?? '',
      applicationStatus: ApplicationStatusX.fromString(
        json['applicationStatus'] as String? ?? 'draft',
      ),
      items: items,
    );
  }
}
