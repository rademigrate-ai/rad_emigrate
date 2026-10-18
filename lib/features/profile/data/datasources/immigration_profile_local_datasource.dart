import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/profile_entity.dart';

/// Local draft persistence for structured immigration profiles.
/// Keys are namespaced per userId for isolation.
class ImmigrationProfileLocalDataSource {
  ImmigrationProfileLocalDataSource(this._prefs);

  final SharedPreferences _prefs;
  static const _keyPrefix = 'rad_immigration_profile_';

  Future<ImmigrationProfile?> read(String userId) async {
    if (userId.isEmpty) return null;
    final raw = _prefs.getString('$_keyPrefix$userId');
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ImmigrationProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String userId, ImmigrationProfile profile) async {
    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }
    await _prefs.setString('$_keyPrefix$userId', jsonEncode(profile.toJson()));
  }

  Future<void> clear(String userId) async {
    if (userId.isEmpty) return;
    await _prefs.remove('$_keyPrefix$userId');
  }
}
