/// Visa application lifecycle statuses.
enum ApplicationStatus {
  draft,
  submitted,
  reviewing,
  documentsRequired,
  approved,
  rejected,
  completed,
}

extension ApplicationStatusX on ApplicationStatus {
  String get label {
    switch (this) {
      case ApplicationStatus.draft:
        return 'Draft';
      case ApplicationStatus.submitted:
        return 'Submitted';
      case ApplicationStatus.reviewing:
        return 'Under Review';
      case ApplicationStatus.documentsRequired:
        return 'Documents Required';
      case ApplicationStatus.approved:
        return 'Approved';
      case ApplicationStatus.rejected:
        return 'Rejected';
      case ApplicationStatus.completed:
        return 'Completed';
    }
  }

  static ApplicationStatus fromString(String value) {
    return ApplicationStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ApplicationStatus.draft,
    );
  }
}
