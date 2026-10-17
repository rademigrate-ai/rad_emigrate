import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/document.dart';

class DocumentLocalDataSource {
  DocumentLocalDataSource(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'rad_documents';

  Future<List<Document>> readAll() async {
    final raw = _prefs.getString(_key);
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
      if (list.any(
        (entry) => (entry as Map<String, dynamic>)['fileUrl'] != null,
      )) {
        await _prefs.setString(_key, jsonEncode(sanitized));
      }
      return sanitized.map(Document.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> writeAll(List<Document> items) async {
    await _prefs.setString(
      _key,
      jsonEncode(items.map((e) => e.toJson()..['fileUrl'] = null).toList()),
    );
  }
}
