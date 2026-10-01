import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/visa_application.dart';

class ApplicationLocalDataSource {
  ApplicationLocalDataSource(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'rad_applications';

  Future<List<VisaApplication>> readAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => VisaApplication.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> writeAll(List<VisaApplication> items) async {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(_key, encoded);
  }
}
