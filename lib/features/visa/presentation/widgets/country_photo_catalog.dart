import 'dart:convert';

import 'package:flutter/services.dart';

/// Content-managed, offline-only resolution. No credentials, remote requests
/// or assumptions of photo permissions based on a URL.
class CountryPhotoCatalog {
  CountryPhotoCatalog({required this.data, required this.assets});

  static const root = 'assets/images/destinations';
  static const fallback = '$root/fallback.jpg';
  final Map<String, dynamic> data;
  final Set<String> assets;

  static Future<CountryPhotoCatalog> load(AssetBundle bundle) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
      final data = jsonDecode(await bundle.loadString('$root/catalog.json'));
      return CountryPhotoCatalog(
        data: data is Map<String, dynamic> ? data : const {},
        assets: manifest.listAssets().toSet(),
      );
    } catch (_) {
      return CountryPhotoCatalog(data: const {}, assets: const {});
    }
  }

  String normalize(String code) {
    final key = code.trim().toUpperCase();
    final aliases = data['aliases'];
    final alias = aliases is Map ? aliases[key] : null;
    return alias is String ? alias.trim().toUpperCase() : key;
  }

  String? _asset(dynamic entry) {
    if (entry is! String ||
        !RegExp(r'^[a-z0-9][a-z0-9_-]*\.(jpg|jpeg|png|webp)$')
            .hasMatch(entry)) {
      return null;
    }
    final path = '$root/$entry';
    return assets.contains(path) ? path : null;
  }

  String resolve(String code, {String? destination}) {
    final destinations = data['destinations'];
    final explicit = destinations is Map
        ? _asset(destinations[destination?.trim().toLowerCase()])
        : null;
    if (explicit != null) return explicit;
    final normalized = normalize(code);
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) return fallback;
    final countries = data['countries'];
    final configured = countries is Map ? _asset(countries[normalized]) : null;
    // Publishing a licensed <iso2>.jpg asset requires no Flutter source edit.
    // A new record without verified photography receives the neutral plate.
    return configured ?? _asset('${normalized.toLowerCase()}.jpg') ?? fallback;
  }
}
