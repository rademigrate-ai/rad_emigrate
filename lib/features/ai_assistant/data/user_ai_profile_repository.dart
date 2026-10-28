import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/supabase_providers.dart';

/// Optional owner-scoped immigration context for AI personalization.
/// Does not invent eligibility outcomes.
class UserAiProfile {
  const UserAiProfile({
    required this.userId,
    this.education,
    this.fieldOfStudy,
    this.workExperience,
    this.languageLevel,
    this.preferredDestinations = const [],
    this.interestedPathways = const [],
    this.budgetRange,
    this.notes,
    this.consentAt,
  });

  final String userId;
  final String? education;
  final String? fieldOfStudy;
  final String? workExperience;
  final String? languageLevel;
  final List<String> preferredDestinations;
  final List<String> interestedPathways;
  final String? budgetRange;
  final String? notes;
  final DateTime? consentAt;

  factory UserAiProfile.fromJson(Map<String, dynamic> json) {
    return UserAiProfile(
      userId: json['user_id'] as String,
      education: json['education'] as String?,
      fieldOfStudy: json['field_of_study'] as String?,
      workExperience: json['work_experience'] as String?,
      languageLevel: json['language_level'] as String?,
      preferredDestinations: (json['preferred_destinations'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      interestedPathways: (json['interested_pathways'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      budgetRange: json['budget_range'] as String?,
      notes: json['notes'] as String?,
      consentAt: json['consent_at'] != null
          ? DateTime.tryParse(json['consent_at'].toString())
          : null,
    );
  }
}

class UserAiProfileRepository {
  const UserAiProfileRepository(this._supabase);
  final SupabaseClientService _supabase;

  Future<UserAiProfile?> fetchMine() async {
    if (!_supabase.isInitialized) return null;
    final uid = _supabase.client.auth.currentUser?.id;
    if (uid == null) return null;
    final rows = await _supabase.client
        .from('user_ai_profiles')
        .select()
        .eq('user_id', uid)
        .limit(1);
    if (rows is! List || rows.isEmpty) return null;
    return UserAiProfile.fromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<UserAiProfile> upsert({
    String? education,
    String? fieldOfStudy,
    String? workExperience,
    String? languageLevel,
    List<String>? preferredDestinations,
    List<String>? interestedPathways,
    String? budgetRange,
    String? notes,
    bool consent = false,
  }) async {
    final result = await _supabase.client.rpc(
      'upsert_user_ai_profile',
      params: {
        'p_education': education,
        'p_field_of_study': fieldOfStudy,
        'p_work_experience': workExperience,
        'p_language_level': languageLevel,
        'p_preferred_destinations': preferredDestinations,
        'p_interested_pathways': interestedPathways,
        'p_budget_range': budgetRange,
        'p_notes': notes,
        'p_consent': consent,
      },
    );
    if (result is Map) {
      return UserAiProfile.fromJson(Map<String, dynamic>.from(result));
    }
    throw const FormatException('invalid_profile_response');
  }

  Future<void> deleteMine() async {
    final uid = _supabase.client.auth.currentUser?.id;
    if (uid == null) return;
    await _supabase.client.from('user_ai_profiles').delete().eq('user_id', uid);
  }
}

final userAiProfileRepositoryProvider = Provider<UserAiProfileRepository>(
  (ref) => UserAiProfileRepository(ref.watch(supabaseClientServiceProvider)),
);
