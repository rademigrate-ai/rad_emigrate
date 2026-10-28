import 'package:flutter/foundation.dart';

/// Voluntary, user-controlled immigration profile used to enhance AI responses.
@immutable
class AiImmigrationProfile {
  final String education;
  final int workExperienceYears;
  final String languageScore;
  final String targetCountry;
  final String estimatedBudget;
  final bool enableAiPersonalization;

  const AiImmigrationProfile({
    this.education = '',
    this.workExperienceYears = 0,
    this.languageScore = '',
    this.targetCountry = '',
    this.estimatedBudget = '',
    this.enableAiPersonalization = true,
  });

  bool get hasContent =>
      education.isNotEmpty ||
      workExperienceYears > 0 ||
      languageScore.isNotEmpty ||
      targetCountry.isNotEmpty ||
      estimatedBudget.isNotEmpty;

  AiImmigrationProfile copyWith({
    String? education,
    int? workExperienceYears,
    String? languageScore,
    String? targetCountry,
    String? estimatedBudget,
    bool? enableAiPersonalization,
  }) {
    return AiImmigrationProfile(
      education: education ?? this.education,
      workExperienceYears: workExperienceYears ?? this.workExperienceYears,
      languageScore: languageScore ?? this.languageScore,
      targetCountry: targetCountry ?? this.targetCountry,
      estimatedBudget: estimatedBudget ?? this.estimatedBudget,
      enableAiPersonalization:
          enableAiPersonalization ?? this.enableAiPersonalization,
    );
  }

  Map<String, String> toAiContext() {
    if (!enableAiPersonalization) return const {};
    return {
      if (education.isNotEmpty) 'education': education,
      if (workExperienceYears > 0) 'experience_years': '$workExperienceYears',
      if (languageScore.isNotEmpty) 'language': languageScore,
      if (targetCountry.isNotEmpty) 'target_country': targetCountry,
      if (estimatedBudget.isNotEmpty) 'budget': estimatedBudget,
    };
  }
}
