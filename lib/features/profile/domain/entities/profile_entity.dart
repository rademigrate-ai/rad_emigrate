// Immigration profile domain models for RAD Emigrate.
// Pure domain logic only. Does not encode visa eligibility rules,
// government requirements, or outcome predictions.

/// Explicit status of a single profile field.
enum ProfileFieldStatus {
  /// Value is present and non-empty after normalization.
  provided,

  /// User or system has not supplied a value yet.
  notProvided,

  /// Value exists but fails basic structural validation (e.g. bad email).
  invalid,

  /// Intentionally marked as unknown / prefer-not-to-say.
  unknown,
}

/// Identifiers for fields that contribute to profile completeness.
enum ImmigrationProfileField {
  fullName,
  email,
  phone,
  nationality,
  education,
  workExperience,
  languages,
  destinationPreference,
  maritalStatus,
}

extension ImmigrationProfileFieldX on ImmigrationProfileField {
  String get key {
    switch (this) {
      case ImmigrationProfileField.fullName:
        return 'fullName';
      case ImmigrationProfileField.email:
        return 'email';
      case ImmigrationProfileField.phone:
        return 'phone';
      case ImmigrationProfileField.nationality:
        return 'nationality';
      case ImmigrationProfileField.education:
        return 'education';
      case ImmigrationProfileField.workExperience:
        return 'workExperience';
      case ImmigrationProfileField.languages:
        return 'languages';
      case ImmigrationProfileField.destinationPreference:
        return 'destinationPreference';
      case ImmigrationProfileField.maritalStatus:
        return 'maritalStatus';
    }
  }
}

/// Immutable immigration profile with explicit unknown/not-provided handling.
class ImmigrationProfile {
  const ImmigrationProfile({
    this.fullName,
    this.email,
    this.phone,
    this.nationality,
    this.education,
    this.workExperience,
    this.languages = const [],
    this.destinationPreference,
    this.maritalStatus,
    this.unknownFields = const {},
  });

  final String? fullName;
  final String? email;
  final String? phone;
  final String? nationality;
  final String? education;
  final String? workExperience;
  final List<String> languages;
  final String? destinationPreference;
  final String? maritalStatus;

  /// Fields the user explicitly marked as unknown / prefer-not-to-say.
  final Set<ImmigrationProfileField> unknownFields;

  ImmigrationProfile copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? nationality,
    String? education,
    String? workExperience,
    List<String>? languages,
    String? destinationPreference,
    String? maritalStatus,
    Set<ImmigrationProfileField>? unknownFields,
  }) {
    return ImmigrationProfile(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      nationality: nationality ?? this.nationality,
      education: education ?? this.education,
      workExperience: workExperience ?? this.workExperience,
      languages: languages ?? this.languages,
      destinationPreference:
          destinationPreference ?? this.destinationPreference,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      unknownFields: unknownFields ?? this.unknownFields,
    );
  }

  /// Marks a field as explicitly unknown and clears its value.
  ImmigrationProfile markUnknown(ImmigrationProfileField field) {
    final nextUnknown = {...unknownFields, field};
    switch (field) {
      case ImmigrationProfileField.fullName:
        return copyWith(fullName: '', unknownFields: nextUnknown);
      case ImmigrationProfileField.email:
        return copyWith(email: '', unknownFields: nextUnknown);
      case ImmigrationProfileField.phone:
        return copyWith(phone: '', unknownFields: nextUnknown);
      case ImmigrationProfileField.nationality:
        return copyWith(nationality: '', unknownFields: nextUnknown);
      case ImmigrationProfileField.education:
        return copyWith(education: '', unknownFields: nextUnknown);
      case ImmigrationProfileField.workExperience:
        return copyWith(workExperience: '', unknownFields: nextUnknown);
      case ImmigrationProfileField.languages:
        return copyWith(languages: const [], unknownFields: nextUnknown);
      case ImmigrationProfileField.destinationPreference:
        return copyWith(destinationPreference: '', unknownFields: nextUnknown);
      case ImmigrationProfileField.maritalStatus:
        return copyWith(maritalStatus: '', unknownFields: nextUnknown);
    }
  }

  /// Clears the unknown flag and sets a concrete value.
  ImmigrationProfile provide(
    ImmigrationProfileField field, {
    String? value,
    List<String>? languageList,
  }) {
    final nextUnknown = {...unknownFields}..remove(field);
    switch (field) {
      case ImmigrationProfileField.fullName:
        return copyWith(fullName: value, unknownFields: nextUnknown);
      case ImmigrationProfileField.email:
        return copyWith(email: value, unknownFields: nextUnknown);
      case ImmigrationProfileField.phone:
        return copyWith(phone: value, unknownFields: nextUnknown);
      case ImmigrationProfileField.nationality:
        return copyWith(nationality: value, unknownFields: nextUnknown);
      case ImmigrationProfileField.education:
        return copyWith(education: value, unknownFields: nextUnknown);
      case ImmigrationProfileField.workExperience:
        return copyWith(workExperience: value, unknownFields: nextUnknown);
      case ImmigrationProfileField.languages:
        return copyWith(
          languages: languageList ?? const [],
          unknownFields: nextUnknown,
        );
      case ImmigrationProfileField.destinationPreference:
        return copyWith(
          destinationPreference: value,
          unknownFields: nextUnknown,
        );
      case ImmigrationProfileField.maritalStatus:
        return copyWith(maritalStatus: value, unknownFields: nextUnknown);
    }
  }

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'nationality': nationality,
    'education': education,
    'workExperience': workExperience,
    'languages': languages,
    'destinationPreference': destinationPreference,
    'maritalStatus': maritalStatus,
    'unknownFields': unknownFields.map((f) => f.key).toList(),
  };

  factory ImmigrationProfile.fromJson(Map<String, dynamic> json) {
    final unknownRaw = json['unknownFields'];
    final unknown = <ImmigrationProfileField>{};
    if (unknownRaw is List) {
      for (final item in unknownRaw) {
        final key = item?.toString();
        if (key == null) continue;
        for (final f in ImmigrationProfileField.values) {
          if (f.key == key) {
            unknown.add(f);
            break;
          }
        }
      }
    }
    final languagesRaw = json['languages'];
    final languages = languagesRaw is List
        ? languagesRaw.map((e) => e.toString()).toList()
        : <String>[];
    return ImmigrationProfile(
      fullName: json['fullName'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      nationality: json['nationality'] as String?,
      education: json['education'] as String?,
      workExperience: json['workExperience'] as String?,
      languages: languages,
      destinationPreference: json['destinationPreference'] as String?,
      maritalStatus: json['maritalStatus'] as String?,
      unknownFields: unknown,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImmigrationProfile &&
          runtimeType == other.runtimeType &&
          fullName == other.fullName &&
          email == other.email &&
          phone == other.phone &&
          nationality == other.nationality &&
          education == other.education &&
          workExperience == other.workExperience &&
          _listEquals(languages, other.languages) &&
          destinationPreference == other.destinationPreference &&
          maritalStatus == other.maritalStatus &&
          _setEquals(unknownFields, other.unknownFields);

  @override
  int get hashCode => Object.hash(
    fullName,
    email,
    phone,
    nationality,
    education,
    workExperience,
    Object.hashAll(languages),
    destinationPreference,
    maritalStatus,
    Object.hashAll(unknownFields),
  );
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _setEquals(
  Set<ImmigrationProfileField> a,
  Set<ImmigrationProfileField> b,
) {
  if (a.length != b.length) return false;
  return a.containsAll(b);
}
