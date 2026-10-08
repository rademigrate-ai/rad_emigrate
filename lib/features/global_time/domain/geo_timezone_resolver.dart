import 'city.dart';
import 'city_catalog.dart';
import 'geo_bootstrap.dart';
import 'geo_lookup.dart';

/// Result of resolving geographic coordinates to an IANA timezone.
enum GeoResolveStatus { resolved, unresolved, unavailable }

class GeoResolveResult {
  const GeoResolveResult({
    required this.status,
    this.ianaId,
    this.latitude,
    this.longitude,
    this.suggestedCity,
  });

  final GeoResolveStatus status;
  final String? ianaId;
  final double? latitude;
  final double? longitude;
  final City? suggestedCity;

  bool get isResolved => status == GeoResolveStatus.resolved && ianaId != null;

  City? toCity() {
    if (!isResolved) return null;
    final id = ianaId!;
    final lat = latitude ?? 0;
    final lng = longitude ?? 0;

    final byTz = CityCatalog.all.where((c) => c.timezone == id).toList();
    if (byTz.isNotEmpty) {
      final best = byTz.reduce((a, b) {
        final da = _dist2(lat, lng, a.latitude, a.longitude);
        final db = _dist2(lat, lng, b.latitude, b.longitude);
        return da <= db ? a : b;
      });
      return City(
        id: 'geo_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
        nameEn: best.nameEn,
        nameFa: best.nameFa,
        countryCode: best.countryCode,
        timezone: id,
        latitude: lat,
        longitude: lng,
        flagEmoji: best.flagEmoji,
      );
    }

    final short = id.contains('/')
        ? id.split('/').last.replaceAll('_', ' ')
        : id;
    return City(
      id: 'geo_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
      nameEn: short,
      nameFa: short,
      countryCode: '',
      timezone: id,
      latitude: lat,
      longitude: lng,
    );
  }

  static double _dist2(double lat1, double lon1, double lat2, double lon2) {
    final dLat = lat1 - lat2;
    final dLon = lon1 - lon2;
    return dLat * dLat + dLon * dLon;
  }
}

abstract final class GeoTimezoneResolver {
  static bool _ready = false;
  static bool _failed = false;

  static Future<void> ensureReady() async {
    if (_ready || _failed) return;
    try {
      await bootstrapGeoTimezone();
      _ready = true;
    } catch (_) {
      _failed = true;
    }
  }

  static Future<GeoResolveResult> resolve({
    required double latitude,
    required double longitude,
  }) async {
    await ensureReady();
    if (_failed || !_ready) {
      return GeoResolveResult(
        status: GeoResolveStatus.unavailable,
        latitude: latitude,
        longitude: longitude,
        suggestedCity: CityCatalog.nearest(latitude, longitude),
      );
    }

    try {
      final name = lookupIanaTimezone(longitude: longitude, latitude: latitude);
      if (name == null) {
        return GeoResolveResult(
          status: GeoResolveStatus.unresolved,
          latitude: latitude,
          longitude: longitude,
          suggestedCity: CityCatalog.nearest(latitude, longitude),
        );
      }
      return GeoResolveResult(
        status: GeoResolveStatus.resolved,
        ianaId: name,
        latitude: latitude,
        longitude: longitude,
        suggestedCity: CityCatalog.nearest(latitude, longitude),
      );
    } catch (_) {
      return GeoResolveResult(
        status: GeoResolveStatus.unavailable,
        latitude: latitude,
        longitude: longitude,
        suggestedCity: CityCatalog.nearest(latitude, longitude),
      );
    }
  }

  static City cityWithManualTimezone({
    required double latitude,
    required double longitude,
    required String ianaId,
    String? nameEn,
    String? nameFa,
  }) {
    final suggested = CityCatalog.nearest(latitude, longitude);
    return City(
      id: 'manual_${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}',
      nameEn: nameEn ?? suggested.nameEn,
      nameFa: nameFa ?? suggested.nameFa,
      countryCode: suggested.countryCode,
      timezone: ianaId,
      latitude: latitude,
      longitude: longitude,
      flagEmoji: suggested.flagEmoji,
    );
  }

  static List<String> get commonIanaIds {
    return [
      for (final c in CityCatalog.all) c.timezone,
      'UTC',
      'Etc/UTC',
      'Asia/Kolkata',
      'Pacific/Auckland',
      'America/Chicago',
      'America/Denver',
      'Europe/Istanbul',
      'Asia/Shanghai',
    ].toSet().toList()..sort();
  }
}
