import 'package:timezone/timezone.dart' as tz;
import 'package:timezone_finder/timezone_finder.dart' as tf;

import 'city.dart';
import 'city_catalog.dart';
import 'timezone_engine.dart';

/// Result of resolving geographic coordinates to an IANA timezone.
enum GeoResolveStatus {
  /// Land polygon matched an IANA zone.
  resolved,

  /// Ocean / no land zone covers this point.
  unresolved,

  /// Boundary data not ready or lookup failed.
  unavailable,
}

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

  /// Optional nearest catalog city for naming only — never used to invent TZ.
  final City? suggestedCity;

  bool get isResolved => status == GeoResolveStatus.resolved && ianaId != null;

  /// Build a selectable City when resolved. Name prefers catalog match by TZ.
  City? toCity() {
    if (!isResolved) return null;
    final id = ianaId!;
    final lat = latitude ?? 0;
    final lng = longitude ?? 0;

    // Prefer catalog city that shares the same IANA id (for localized name).
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

    // Fallback: use IANA id as display name; user can rename via favorites later.
    final short = id.contains('/') ? id.split('/').last.replaceAll('_', ' ') : id;
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

/// Latitude/longitude → IANA using Timezone Boundary Builder polygons
/// via `timezone_finder` (not nearest-city guessing).
abstract final class GeoTimezoneResolver {
  static bool _ready = false;
  static bool _failed = false;

  static Future<void> ensureReady() async {
    if (_ready || _failed) return;
    try {
      await TimezoneEngine.ensureInitialized();
      // On VM/native, boundaries are compiled in. On web, caller should
      // install the .bin asset first; if not available we mark unavailable.
      await tf.ensurePreloaded();
      _ready = true;
    } catch (_) {
      _failed = true;
    }
  }

  /// GeoJSON order: longitude, latitude.
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
      // timezone_finder API: findLocation(longitude, latitude)
      final loc = tf.findLocation(longitude, latitude);
      if (loc == null) {
        return GeoResolveResult(
          status: GeoResolveStatus.unresolved,
          latitude: latitude,
          longitude: longitude,
          suggestedCity: CityCatalog.nearest(latitude, longitude),
        );
      }
      return GeoResolveResult(
        status: GeoResolveStatus.resolved,
        ianaId: loc.name,
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

  /// Manual override when automatic resolution fails.
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
    ].toSet().toList()..
sort();
  }
}
