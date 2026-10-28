/// Shared contract between Grok backend profile persistence and Antigravity UI.
///
/// Antigravity currently stores [AiImmigrationProfile] in device SharedPreferences.
/// Server tables (`user_ai_profiles`) are optional cloud backup after migration apply.
/// Field mapping is explicit so neither side invents eligibility outcomes.

library;

/// Canonical keys accepted in AI request context when user consents to personalization.
const kAiProfileContextKeys = <String>{
  'education',
  'experience_years',
  'language',
  'target_country',
  'budget',
  'field_of_study',
  'work_experience',
  'language_level',
  'preferred_destinations',
  'interested_pathways',
  'budget_range',
  'notes',
};

/// Map Antigravity device-local profile fields → server upsert params.
Map<String, dynamic> antigravityProfileToServerParams({
  required String education,
  required int workExperienceYears,
  required String languageScore,
  required String targetCountry,
  required String estimatedBudget,
  required bool consent,
}) {
  return {
    'p_education': education.isEmpty ? null : education,
    'p_work_experience': workExperienceYears > 0
        ? '$workExperienceYears years'
        : null,
    'p_language_level': languageScore.isEmpty ? null : languageScore,
    'p_preferred_destinations': targetCountry.isEmpty
        ? <String>[]
        : <String>[targetCountry],
    'p_budget_range': estimatedBudget.isEmpty ? null : estimatedBudget,
    'p_consent': consent,
  };
}

/// Map server row → Antigravity-friendly context bag for orchestrator.
Map<String, String> serverProfileToAiContext(Map<String, dynamic> row) {
  final out = <String, String>{};
  void put(String key, Object? value) {
    if (value == null) return;
    final s = value.toString().trim();
    if (s.isEmpty) return;
    out[key] = s;
  }

  put('education', row['education']);
  put('field_of_study', row['field_of_study']);
  put('work_experience', row['work_experience']);
  put('language_level', row['language_level']);
  put('budget_range', row['budget_range']);
  put('notes', row['notes']);
  final dest = row['preferred_destinations'];
  if (dest is List && dest.isNotEmpty) {
    out['preferred_destinations'] = dest.join(', ');
    out['target_country'] = dest.first.toString();
  }
  final paths = row['interested_pathways'];
  if (paths is List && paths.isNotEmpty) {
    out['interested_pathways'] = paths.join(', ');
  }
  return out;
}
