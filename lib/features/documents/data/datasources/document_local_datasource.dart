import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/document.dart';

class DocumentLocalDataSource {
  DocumentLocalDataSource(this._prefs);

  final SharedPreferences _prefs;
  static String keyFor(String userId) =>
      'rad_documents_${Uri.encodeComponent(userId)}';

  Future<List<Document>> readAll({required String userId}) async {
    // Ownership of the old shared blob is not established for this reader.
    await _prefs.remove('rad_documents');
    if (userId.trim().isEmpty) return [];
    final raw = _prefs.getString(keyFor(userId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final sanitized = list.map((entry) {
        final item = Map<String, dynamic>.from(entry as Map<String, dynamic>);
        // Legacy clients cached signed private download URLs. Never restore
        // or keep a bearer-token link in persistent preferences.
        item['fileUrl'] = null;
        return item;
      }).toList();
      final owned = sanitized
          .map(Document.fromJson)
          .where((item) => item.userId == userId)
          .toList();
      await writeAll(owned, userId: userId);
      return owned;
    } catch (_) {
      return [];
    }
  }

  Future<void> writeAll(List<Document> items, {required String userId}) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('Document cache requires an owner');
    }
    await _prefs.setString(
      keyFor(userId),
      jsonEncode(
        items
            .where((item) => item.userId == userId)
            .map((e) => e.toJson()..['fileUrl'] = null)
            .toList(),
      ),
    );
    await _prefs.remove('rad_documents');
  }
}
