import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Stable anonymous guest key for server-side 5-question quota.
/// Not authentication. Server stores only SHA-256 of this key.
class AiGuestIdentity {
  AiGuestIdentity._();

  static const _prefsKey = 'rad_ai_guest_key_v1';
  static const _keyLength = 32;

  /// Returns a persisted high-entropy guest key (creates one if missing).
  static Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsKey);
    if (existing != null && existing.length >= 16) {
      return existing;
    }
    final key = _generate();
    await prefs.setString(_prefsKey, key);
    return key;
  }

  /// Clears guest identity (e.g. after successful login). Optional.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static String _generate() {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return List.generate(
      _keyLength,
      (_) => alphabet[rnd.nextInt(alphabet.length)],
    ).join();
  }
}
