import 'entities/profile_entity.dart';

/// Structural validation and completeness for [ImmigrationProfile].
///
/// Completeness is a deterministic percentage of fields that are either
/// provided with valid structure or explicitly marked unknown.
/// It does **not** encode legal eligibility or government requirements.
class ImmigrationProfileValidator {
  ImmigrationProfileValidator._();

  static final _emailPattern = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
  );

  /// Minimal E.164-ish phone: optional +, digits, spaces, dashes, parentheses.
  static final _phonePattern = RegExp(r'^\+?[0-9\s\-().]{7,20}$');

  /// All fields considered for completeness scoring.
  static const List<ImmigrationProfileField> scoredFields =
      ImmigrationProfileField.values;

  /// Returns status of every scored field.
  static Map<ImmigrationProfileField, ProfileFieldStatus> fieldStatuses(
    ImmigrationProfile profile,
  ) {
    final result = <ImmigrationProfileField, ProfileFieldStatus>{};
    for (final field in scoredFields) {
      result[field] = statusOf(profile, field);
    }
    return result;
  }

  static ProfileFieldStatus statusOf(
    ImmigrationProfile profile,
    ImmigrationProfileField field,
  ) {
    if (profile.unknownFields.contains(field)) {
      return ProfileFieldStatus.unknown;
    }
    switch (field) {
      case ImmigrationProfileField.fullName:
        return _stringStatus(profile.fullName, minLength: 2);
      case ImmigrationProfileField.email:
        return _emailStatus(profile.email);
      case ImmigrationProfileField.phone:
        return _phoneStatus(profile.phone);
      case ImmigrationProfileField.nationality:
        return _stringStatus(profile.nationality, minLength: 2);
      case ImmigrationProfileField.education:
        return _stringStatus(profile.education, minLength: 2);
      case ImmigrationProfileField.workExperience:
        return _stringStatus(profile.workExperience, minLength: 2);
      case ImmigrationProfileField.languages:
        return _languagesStatus(profile.languages);
      case ImmigrationProfileField.destinationPreference:
        return _stringStatus(profile.destinationPreference, minLength: 2);
      case ImmigrationProfileField.maritalStatus:
        return _stringStatus(profile.maritalStatus, minLength: 2);
    }
  }

  static ProfileFieldStatus _stringStatus(String? raw, {int minLength = 1}) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return ProfileFieldStatus.notProvided;
    if (v.length < minLength) return ProfileFieldStatus.invalid;
    return ProfileFieldStatus.provided;
  }

  static ProfileFieldStatus _emailStatus(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return ProfileFieldStatus.notProvided;
    if (!_emailPattern.hasMatch(v)) return ProfileFieldStatus.invalid;
    return ProfileFieldStatus.provided;
  }

  static ProfileFieldStatus _phoneStatus(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return ProfileFieldStatus.notProvided;
    if (!_phonePattern.hasMatch(v)) return ProfileFieldStatus.invalid;
    return ProfileFieldStatus.provided;
  }

  static ProfileFieldStatus _languagesStatus(List<String> languages) {
    final cleaned = languages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) return ProfileFieldStatus.notProvided;
    return ProfileFieldStatus.provided;
  }

  /// Completeness in [0.0, 1.0].
  ///
  /// A field counts toward completeness when it is [ProfileFieldStatus.provided]
  /// or [ProfileFieldStatus.unknown]. Invalid and not-provided do not.
  static double completenessRatio(ImmigrationProfile profile) {
    if (scoredFields.isEmpty) return 0.0;
    var complete = 0;
    for (final field in scoredFields) {
      final status = statusOf(profile, field);
      if (status == ProfileFieldStatus.provided ||
          status == ProfileFieldStatus.unknown) {
        complete++;
      }
    }
    return complete / scoredFields.length;
  }

  /// Integer percent 0–100.
  static int completenessPercent(ImmigrationProfile profile) {
    return (completenessRatio(profile) * 100).round();
  }

  /// Fields that still need attention (not provided or invalid).
  static List<ImmigrationProfileField> incompleteFields(
    ImmigrationProfile profile,
  ) {
    final out = <ImmigrationProfileField>[];
    for (final field in scoredFields) {
      final status = statusOf(profile, field);
      if (status == ProfileFieldStatus.notProvided ||
          status == ProfileFieldStatus.invalid) {
        out.add(field);
      }
    }
    return out;
  }

  /// Fields with structural validation failures.
  static List<ImmigrationProfileField> invalidFields(
    ImmigrationProfile profile,
  ) {
    final out = <ImmigrationProfileField>[];
    for (final field in scoredFields) {
      if (statusOf(profile, field) == ProfileFieldStatus.invalid) {
        out.add(field);
      }
    }
    return out;
  }

  /// True when every scored field is either provided or explicitly unknown,
  /// and none are invalid.
  static bool isStructurallyComplete(ImmigrationProfile profile) {
    return incompleteFields(profile).isEmpty && invalidFields(profile).isEmpty;
  }

  /// Aggregated validation result for UI / persistence gates.
  static ImmigrationProfileValidationResult validate(
    ImmigrationProfile profile,
  ) {
    final statuses = fieldStatuses(profile);
    final invalid = <ImmigrationProfileField>[];
    final missing = <ImmigrationProfileField>[];
    for (final entry in statuses.entries) {
      switch (entry.value) {
        case ProfileFieldStatus.invalid:
          invalid.add(entry.key);
        case ProfileFieldStatus.notProvided:
          missing.add(entry.key);
        case ProfileFieldStatus.provided:
        case ProfileFieldStatus.unknown:
          break;
      }
    }
    return ImmigrationProfileValidationResult(
      statuses: statuses,
      invalidFields: invalid,
      missingFields: missing,
      completenessPercent: completenessPercent(profile),
      isStructurallyComplete: invalid.isEmpty && missing.isEmpty,
    );
  }
}

/// Result of [ImmigrationProfileValidator.validate].
class ImmigrationProfileValidationResult {
  const ImmigrationProfileValidationResult({
    required this.statuses,
    required this.invalidFields,
    required this.missingFields,
    required this.completenessPercent,
    required this.isStructurallyComplete,
  });

  final Map<ImmigrationProfileField, ProfileFieldStatus> statuses;
  final List<ImmigrationProfileField> invalidFields;
  final List<ImmigrationProfileField> missingFields;
  final int completenessPercent;
  final bool isStructurallyComplete;

  bool get hasErrors => invalidFields.isNotEmpty;
  bool get hasMissing => missingFields.isNotEmpty;
}
