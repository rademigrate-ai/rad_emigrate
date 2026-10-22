import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/visa_application.dart';

/// Local cache for visa applications.
///
/// Keys are scoped per [userId] to prevent cross-account draft leakage on
/// shared devices. This is **not** a substitute for Supabase RLS.
class ApplicationLocalDataSource {
  ApplicationLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  /// Legacy unscoped key (pre-hardening). Migrated away on first scoped write.
  static const _legacyKey = 'rad_applications';
  static const _keyPrefix = 'rad_applications_';

  String _keyFor(String userId) => '$_keyPrefix$userId';

  Future<List<VisaApplication>> readAll({String? userId}) async {
    if (userId != null && userId.isNotEmpty) {
      return readForUser(userId);
    }
    await clearLegacyUnscoped();
    return [];
  }

  Future<List<VisaApplication>> readForUser(String userId) async {
    if (userId.isEmpty) return [];
    final items = await _readKey(_keyFor(userId));
    return items.where((item) => item.userId == userId).toList();
  }

  Future<void> writeForUser(String userId, List<VisaApplication> items) async {
    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }
    // Only persist rows owned by this user (defense in depth).
    final owned = items.where((e) => e.userId == userId).toList();
    final encoded = jsonEncode(owned.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyFor(userId), encoded);
    // Drop legacy unscoped blob if present.
    if (_prefs.containsKey(_legacyKey)) {
      await _prefs.remove(_legacyKey);
    }
  }

  /// @Deprecated Prefer [writeForUser]. Writes legacy key only when userId omitted.
  Future<void> writeAll(List<VisaApplication> items) async {
    for (final owner
        in items
            .map((item) => item.userId)
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()) {
      await writeForUser(
        owner,
        items.where((item) => item.userId == owner).toList(),
      );
    }
    await clearLegacyUnscoped();
  }

  Future<void> clearForUser(String userId) async {
    if (userId.isEmpty) return;
    await _prefs.remove(_keyFor(userId));
  }

  /// Removes legacy unscoped cache (call on logout / account switch).
  Future<void> clearLegacyUnscoped() async {
    await _prefs.remove(_legacyKey);
  }

  Future<List<VisaApplication>> _readKey(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => VisaApplication.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupted payload: fail closed to empty rather than crash.
      return [];
    }
  }
}
