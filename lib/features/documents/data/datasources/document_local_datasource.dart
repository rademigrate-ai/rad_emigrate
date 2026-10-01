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
      return list
          .map((e) => Document.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> writeAll(List<Document> items) async {
    await _prefs.setString(
      _key,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }
}
