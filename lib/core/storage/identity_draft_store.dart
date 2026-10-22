import 'package:shared_preferences/shared_preferences.dart';

/// Account-bound local drafts. A guest handoff requires an explicit sign-in
/// action; authenticated drafts never become guest or another account's data.
class IdentityDraftStore {
  IdentityDraftStore(this.keys, {this.userId});
  final List<String> keys;
  final String? userId;
  String scoped(String key) =>
      '$key::${userId == null ? 'guest' : 'user:$userId'}';
  String get _handoff => '${keys.first}::sign-in-handoff';

  Future<Map<String, String?>> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Legacy unscoped drafts have no provable owner; never attribute them.
    for (final key in keys) {
      await prefs.remove(key);
    }
    if (userId != null && prefs.getBool(_handoff) == true) {
      await prefs.remove(_handoff);
      for (final key in keys) {
        final guestKey = '$key::guest';
        final value = prefs.getString(guestKey);
        if (value != null) await prefs.setString(scoped(key), value);
        await prefs.remove(guestKey);
      }
    }
    return {for (final key in keys) key: prefs.getString(scoped(key))};
  }

  Future<void> signInHandoff() async {
    if (userId != null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_handoff, true);
  }

  Future<void> write(String key, String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(scoped(key));
    } else {
      await prefs.setString(scoped(key), value);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in keys) {
      await prefs.remove(scoped(key));
    }
    if (userId == null) await prefs.remove(_handoff);
  }
}
