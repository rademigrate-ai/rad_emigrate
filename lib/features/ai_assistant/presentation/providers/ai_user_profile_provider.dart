import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/user_ai_profile_repository.dart';
import '../../domain/entities/ai_user_profile.dart';

/// Encrypted local cache for voluntary immigration profile fields.
/// SharedPreferences is never used for sensitive profile values going forward;
/// any legacy plaintext keys are deleted on load/clear.
const _secure = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

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
        // Clear in-memory state immediately on logout / user switch.
        state = const AiImmigrationProfile();
        _currentUserId = next;
        _loadProfile(next);
      }
    });
  }

  String _k(String userId, String field) =>
      'ai_profile_secure_${userId}_$field';

  int _parseYears(String? value) {
    if (value == null || value.isEmpty) return 0;
    final match = RegExp(r'\d+').firstMatch(value);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  /// Remove legacy plaintext SharedPreferences keys for this user (one-time hygiene).
  Future<void> _purgeLegacyPlaintext(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyPrefix = 'ai_profile_${userId}_';
      await prefs.remove('${keyPrefix}education');
      await prefs.remove('${keyPrefix}experience');
      await prefs.remove('${keyPrefix}language');
      await prefs.remove('${keyPrefix}country');
      await prefs.remove('${keyPrefix}budget');
      await prefs.remove('${keyPrefix}enabled');
    } catch (_) {}
  }

  Future<void> _writeSecure(String userId, AiImmigrationProfile profile) async {
    await _secure.write(key: _k(userId, 'education'), value: profile.education);
    await _secure.write(
      key: _k(userId, 'experience'),
      value: '${profile.workExperienceYears}',
    );
    await _secure.write(
      key: _k(userId, 'language'),
      value: profile.languageScore,
    );
    await _secure.write(
      key: _k(userId, 'country'),
      value: profile.targetCountry,
    );
    await _secure.write(
      key: _k(userId, 'budget'),
      value: profile.estimatedBudget,
    );
    await _secure.write(
      key: _k(userId, 'enabled'),
      value: profile.enableAiPersonalization ? '1' : '0',
    );
  }

  Future<void> _deleteSecure(String userId) async {
    for (final field in [
      'education',
      'experience',
      'language',
      'country',
      'budget',
      'enabled',
    ]) {
      await _secure.delete(key: _k(userId, field));
    }
  }

  Future<AiImmigrationProfile?> _readSecure(String userId) async {
    final education = await _secure.read(key: _k(userId, 'education'));
    final experience = await _secure.read(key: _k(userId, 'experience'));
    final language = await _secure.read(key: _k(userId, 'language'));
    final country = await _secure.read(key: _k(userId, 'country'));
    final budget = await _secure.read(key: _k(userId, 'budget'));
    final enabled = await _secure.read(key: _k(userId, 'enabled'));
    if (education == null &&
        experience == null &&
        language == null &&
        country == null &&
        budget == null) {
      return null;
    }
    return AiImmigrationProfile(
      education: education ?? '',
      workExperienceYears: int.tryParse(experience ?? '') ?? 0,
      languageScore: language ?? '',
      targetCountry: country ?? '',
      estimatedBudget: budget ?? '',
      enableAiPersonalization: enabled != '0',
    );
  }

  Future<void> _loadProfile(String? userId) async {
    if (userId == null || userId.isEmpty) {
      state = const AiImmigrationProfile();
      return;
    }
    try {
      await _purgeLegacyPlaintext(userId);

      final secure = await _readSecure(userId);
      if (secure != null && secure.hasContent) {
        state = secure;
        return;
      }

      // Optional cloud restore when local cache empty (owner-scoped RPC).
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
          await _writeSecure(userId, cloudProfile);
          return;
        }
      } catch (_) {
        // Offline / pre-migration safe fallback
      }

      state = secure ?? const AiImmigrationProfile();
    } catch (_) {
      state = const AiImmigrationProfile();
    }
  }

  Future<void> updateProfile(AiImmigrationProfile profile) async {
    state = profile;
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;
    try {
      await _writeSecure(userId, profile);
      await _purgeLegacyPlaintext(userId);

      try {
        final repo = _ref.read(userAiProfileRepositoryProvider);
        await repo.upsert(
          education: profile.education.isEmpty ? null : profile.education,
          workExperience: profile.workExperienceYears > 0
              ? '${profile.workExperienceYears} years'
              : null,
          languageLevel: profile.languageScore.isEmpty
              ? null
              : profile.languageScore,
          preferredDestinations: profile.targetCountry.isEmpty
              ? []
              : [profile.targetCountry],
          budgetRange: profile.estimatedBudget.isEmpty
              ? null
              : profile.estimatedBudget,
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
      await _deleteSecure(userId);
      await _purgeLegacyPlaintext(userId);
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
