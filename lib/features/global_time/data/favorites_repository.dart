import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/city.dart';
import '../domain/city_catalog.dart';

const _kFavoritesKey = 'rad_global_time_favorites_v1';

class FavoritesRepository {
  FavoritesRepository(this._prefs);

  final SharedPreferences _prefs;

  List<City> load() {
    final raw = _prefs.getString(_kFavoritesKey);
    if (raw == null || raw.isEmpty) {
      return List<City>.from(CityCatalog.defaults);
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final cities = <City>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          cities.add(City.fromJson(item));
        } else if (item is String) {
          final known = CityCatalog.byId(item);
          if (known != null) cities.add(known);
        }
      }
      if (cities.isEmpty) return List<City>.from(CityCatalog.defaults);
      return cities;
    } catch (_) {
      return List<City>.from(CityCatalog.defaults);
    }
  }

  Future<void> save(List<City> cities) async {
    final encoded = jsonEncode(cities.map((c) => c.toJson()).toList());
    await _prefs.setString(_kFavoritesKey, encoded);
  }

  Future<List<City>> add(City city) async {
    final current = load();
    if (current.any((c) => c.id == city.id)) return current;
    final next = [...current, city];
    await save(next);
    return next;
  }

  Future<List<City>> remove(String cityId) async {
    final next = load().where((c) => c.id != cityId).toList();
    await save(next);
    return next;
  }

  Future<List<City>> reorder(List<City> ordered) async {
    await save(ordered);
    return ordered;
  }

  Future<List<City>> restoreDefaults() async {
    final defaults = List<City>.from(CityCatalog.defaults);
    await save(defaults);
    return defaults;
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final favoritesRepositoryProvider = Provider<FavoritesRepository?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  if (prefs == null) return null;
  return FavoritesRepository(prefs);
});
