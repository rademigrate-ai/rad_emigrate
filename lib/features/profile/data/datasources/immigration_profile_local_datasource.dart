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

  /// Clears every immigration-profile draft key (logout / factory reset).
  /// Prefer [clear] with the known userId when available.
  Future<int> clearAllImmigrationDrafts() async {
    final keys = _prefs
        .getKeys()
        .where((k) => k.startsWith(_keyPrefix))
        .toList(growable: false);
    for (final k in keys) {
      await _prefs.remove(k);
    }
    return keys.length;
  }

  /// Returns true when a draft exists for [userId] without decoding it.
  bool hasDraft(String userId) {
    if (userId.isEmpty) return false;
    final raw = _prefs.getString('$_keyPrefix$userId');
    return raw != null && raw.isNotEmpty;
  }
}
