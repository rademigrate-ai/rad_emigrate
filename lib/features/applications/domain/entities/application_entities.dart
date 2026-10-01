enum ApplicationStatus { draft, submitted, underReview, approved, rejected }

extension ApplicationStatusX on ApplicationStatus {
  String get label {
    switch (this) {
      case ApplicationStatus.draft:
        return 'Draft';
      case ApplicationStatus.submitted:
        return 'Submitted';
      case ApplicationStatus.underReview:
        return 'Under Review';
      case ApplicationStatus.approved:
        return 'Approved';
      case ApplicationStatus.rejected:
        return 'Rejected';
    }
  }

  ColorStatus get colorStatus {
    switch (this) {
      case ApplicationStatus.draft:
        return ColorStatus.grey;
      case ApplicationStatus.submitted:
        return ColorStatus.blue;
      case ApplicationStatus.underReview:
        return ColorStatus.orange;
      case ApplicationStatus.approved:
        return ColorStatus.green;
      case ApplicationStatus.rejected:
        return ColorStatus.red;
    }
  }
}

enum ColorStatus { grey, blue, orange, green, red }

class Application {
  final String id;
  final String title;
  final String programName;
  final String country;
  final ApplicationStatus status;
  final DateTime updatedAt;
  final String? notes;

  const Application({
    required this.id,
    required this.title,
    required this.programName,
    required this.country,
    required this.status,
    required this.updatedAt,
    this.notes,
  });
}
