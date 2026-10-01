class ImmigrationProfile {
  final String? fullName;
  final String? email;
  final String? phone;
  final String? nationality;
  final String? education;
  final String? workExperience;
  final List<String> languages;
  final String? destinationPreference;
  final String? maritalStatus;

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
  });

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
    );
  }
}
