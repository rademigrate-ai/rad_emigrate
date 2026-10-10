import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/document.dart';

class DocumentLocalDataSource {
  DocumentLocalDataSource(this._prefs, {required String userId})
    : assert(userId != ''),
      _userId = userId;

  final SharedPreferences _prefs;
  final String _userId;

  static const _legacySharedKey = 'rad_documents';
  static const _keyPrefix = 'rad_documents_v2';

  String get _key => '$_keyPrefix.$_userId';

  Future<void> _removeUnsafeLegacyCache() async {
    // Stage 1 previously stored every account in one shared key. Never read or
    // migrate that value because its owner cannot be established safely.
    if (_prefs.containsKey(_legacySharedKey)) {
      await _prefs.remove(_legacySharedKey);
    }
  }

  Future<List<Document>> readAll() async {
    await _removeUnsafeLegacyCache();
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final owned = list
          .map((e) => Document.fromJson(e as Map<String, dynamic>))
          .where((document) => document.userId == _userId)
          .toList();
      if (owned.length != list.length) await writeAll(owned);
      return owned;
    } catch (_) {
      await _prefs.remove(_key);
      return [];
    }
  }

  Future<void> writeAll(List<Document> items) async {
    await _removeUnsafeLegacyCache();
    final owned = items.where((document) => document.userId == _userId);
    await _prefs.setString(
      _key,
      jsonEncode(
        owned.map((document) {
          // Signed URLs are bearer credentials with a short lifetime. Cache
          // the stable private object path, never the signed URL itself.
          return {...document.toJson(), 'fileUrl': null};
        }).toList(),
      ),
    );
  }

  Future<void> clear() async {
    await _removeUnsafeLegacyCache();
    await _prefs.remove(_key);
  }
}
