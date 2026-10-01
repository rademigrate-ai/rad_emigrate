import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user_profile.dart';

/// Local persistence for immigration profile (no live backend).
class ProfileLocalDataSource {
  ProfileLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  static const _keyPrefix = 'rad_profile_';

  Future<UserProfile?> read(String userId) async {
    final raw = _prefs.getString('$_keyPrefix$userId');
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(UserProfile profile) async {
    await _prefs.setString(
      '$_keyPrefix${profile.id}',
      jsonEncode(profile.toJson()),
    );
  }

  Future<void> clear(String userId) async {
    await _prefs.remove('$_keyPrefix$userId');
  }
}
