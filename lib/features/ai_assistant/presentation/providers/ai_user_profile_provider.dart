import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/user_ai_profile_repository.dart';
import '../../domain/entities/ai_user_profile.dart';

class AiUserProfileNotifier extends StateNotifier<AiImmigrationProfile> {
  AiUserProfileNotifier(this._ref) : super(const AiImmigrationProfile()) {
    _init();
  }

  final Ref _ref;
  String? _currentUserId;

  void _init() {
    _currentUserId = _ref.read(authenticatedUserIdProvider);
    _loadProfile(_currentUserId);

    _ref.listen<String?>(authenticatedUserIdProvider, (previous, next) {
      if (previous != next) {
        _currentUserId = next;
        _loadProfile(next);
      }
    });
  }

  int _parseYears(String? value) {
    if (value == null || value.isEmpty) return 0;
    final match = RegExp(r'\d+').firstMatch(value);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  Future<void> _loadProfile(String? userId) async {
    if (userId == null || userId.isEmpty) {
      state = const AiImmigrationProfile();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyPrefix = 'ai_profile_${userId}_';
      final loaded = AiImmigrationProfile(
        education: prefs.getString('${keyPrefix}education') ?? '',
        workExperienceYears: prefs.getInt('${keyPrefix}experience') ?? 0,
        languageScore: prefs.getString('${keyPrefix}language') ?? '',
        targetCountry: prefs.getString('${keyPrefix}country') ?? '',
        estimatedBudget: prefs.getString('${keyPrefix}budget') ?? '',
        enableAiPersonalization:
            prefs.getBool('${keyPrefix}enabled') ?? true,
      );

      if (loaded.hasContent) {
        state = loaded;
        return;
      }

      // If local SharedPreferences is empty, attempt optional cloud restore
      try {
        final repo = _ref.read(userAiProfileRepositoryProvider);
        final remote = await repo.fetchMine();
        if (remote != null) {
          final cloudProfile = AiImmigrationProfile(
            education: remote.education ?? '',
            workExperienceYears: _parseYears(remote.workExperience),
            languageScore: remote.languageLevel ?? '',
            targetCountry: remote.preferredDestinations.isNotEmpty
                ? remote.preferredDestinations.first
                : '',
            estimatedBudget: remote.budgetRange ?? '',
            enableAiPersonalization: remote.consentAt != null,
          );
          state = cloudProfile;
          // Cache locally
          await prefs.setString('${keyPrefix}education', cloudProfile.education);
          await prefs.setInt(
            '${keyPrefix}experience',
            cloudProfile.workExperienceYears,
          );
          await prefs.setString(
            '${keyPrefix}language',
            cloudProfile.languageScore,
          );
          await prefs.setString(
            '${keyPrefix}country',
            cloudProfile.targetCountry,
          );
          await prefs.setString('${keyPrefix}budget', cloudProfile.estimatedBudget);
          await prefs.setBool(
            '${keyPrefix}enabled',
            cloudProfile.enableAiPersonalization,
          );
          return;
        }
      } catch (_) {
        // Safe offline/fallback behavior
      }

      state = loaded;
    } catch (_) {
      state = const AiImmigrationProfile();
    }
  }

  Future<void> updateProfile(AiImmigrationProfile profile) async {
    state = profile;
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyPrefix = 'ai_profile_${userId}_';
      await prefs.setString('${keyPrefix}education', profile.education);
      await prefs.setInt('${keyPrefix}experience', profile.workExperienceYears);
      await prefs.setString('${keyPrefix}language', profile.languageScore);
      await prefs.setString('${keyPrefix}country', profile.targetCountry);
      await prefs.setString('${keyPrefix}budget', profile.estimatedBudget);
      await prefs.setBool(
        '${keyPrefix}enabled',
        profile.enableAiPersonalization,
      );

      // Attempt optional cloud sync
      try {
        final repo = _ref.read(userAiProfileRepositoryProvider);
        await repo.upsert(
          education: profile.education.isEmpty ? null : profile.education,
          workExperience: profile.workExperienceYears > 0
              ? '${profile.workExperienceYears} years'
              : null,
          languageLevel:
              profile.languageScore.isEmpty ? null : profile.languageScore,
          preferredDestinations: profile.targetCountry.isEmpty
              ? []
              : [profile.targetCountry],
          budgetRange:
              profile.estimatedBudget.isEmpty ? null : profile.estimatedBudget,
          consent: profile.enableAiPersonalization,
        );
      } catch (_) {
        // Safe offline / pre-migration fallback
      }
    } catch (_) {}
  }

  Future<void> clearProfile() async {
    state = const AiImmigrationProfile();
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyPrefix = 'ai_profile_${userId}_';
      await prefs.remove('${keyPrefix}education');
      await prefs.remove('${keyPrefix}experience');
      await prefs.remove('${keyPrefix}language');
      await prefs.remove('${keyPrefix}country');
      await prefs.remove('${keyPrefix}budget');
      await prefs.remove('${keyPrefix}enabled');

      try {
        final repo = _ref.read(userAiProfileRepositoryProvider);
        await repo.deleteMine();
      } catch (_) {}
    } catch (_) {}
  }
}

final aiUserProfileProvider =
    StateNotifierProvider<AiUserProfileNotifier, AiImmigrationProfile>((ref) {
  return AiUserProfileNotifier(ref);
});
