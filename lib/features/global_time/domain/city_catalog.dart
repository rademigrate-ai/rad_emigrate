import 'dart:math' as math;

import 'city.dart';

/// Curated catalog of major cities for search, defaults, and nearest-city fallback.
/// Coordinates are approximate city centers; timezone IDs are canonical IANA.
abstract final class CityCatalog {
  static const List<City> defaults = [
    City(
      id: 'tehran',
      nameEn: 'Tehran',
      nameFa: 'تهران',
      countryCode: 'IR',
      timezone: 'Asia/Tehran',
      latitude: 35.6892,
      longitude: 51.3890,
      flagEmoji: '🇮🇷',
    ),
    City(
      id: 'toronto',
      nameEn: 'Toronto',
      nameFa: 'تورنتو',
      countryCode: 'CA',
      timezone: 'America/Toronto',
      latitude: 43.6532,
      longitude: -79.3832,
      flagEmoji: '🇨🇦',
    ),
    City(
      id: 'london',
      nameEn: 'London',
      nameFa: 'لندن',
      countryCode: 'GB',
      timezone: 'Europe/London',
      latitude: 51.5074,
      longitude: -0.1278,
      flagEmoji: '🇬🇧',
    ),
    City(
      id: 'berlin',
      nameEn: 'Berlin',
      nameFa: 'برلین',
      countryCode: 'DE',
      timezone: 'Europe/Berlin',
      latitude: 52.5200,
      longitude: 13.4050,
      flagEmoji: '🇩🇪',
    ),
    City(
      id: 'dubai',
      nameEn: 'Dubai',
      nameFa: 'دبی',
      countryCode: 'AE',
      timezone: 'Asia/Dubai',
      latitude: 25.2048,
      longitude: 55.2708,
      flagEmoji: '🇦🇪',
    ),
    City(
      id: 'sydney',
      nameEn: 'Sydney',
      nameFa: 'سیدنی',
      countryCode: 'AU',
      timezone: 'Australia/Sydney',
      latitude: -33.8688,
      longitude: 151.2093,
      flagEmoji: '🇦🇺',
    ),
  ];

  /// Extended searchable catalog (defaults + additional common cities).
  static final List<City> all = [
    ...defaults,
    const City(
      id: 'istanbul',
      nameEn: 'Istanbul',
      nameFa: 'استانبول',
      countryCode: 'TR',
      timezone: 'Europe/Istanbul',
      latitude: 41.0082,
      longitude: 28.9784,
      flagEmoji: '🇹🇷',
    ),
    const City(
      id: 'new_york',
      nameEn: 'New York',
      nameFa: 'نیویورک',
      countryCode: 'US',
      timezone: 'America/New_York',
      latitude: 40.7128,
      longitude: -74.0060,
      flagEmoji: '🇺🇸',
    ),
    const City(
      id: 'los_angeles',
      nameEn: 'Los Angeles',
      nameFa: 'لس آنجلس',
      countryCode: 'US',
      timezone: 'America/Los_Angeles',
      latitude: 34.0522,
      longitude: -118.2437,
      flagEmoji: '🇺🇸',
    ),
    const City(
      id: 'paris',
      nameEn: 'Paris',
      nameFa: 'پاریس',
      countryCode: 'FR',
      timezone: 'Europe/Paris',
      latitude: 48.8566,
      longitude: 2.3522,
      flagEmoji: '🇫🇷',
    ),
    const City(
      id: 'tokyo',
      nameEn: 'Tokyo',
      nameFa: 'توکیو',
      countryCode: 'JP',
      timezone: 'Asia/Tokyo',
      latitude: 35.6762,
      longitude: 139.6503,
      flagEmoji: '🇯🇵',
    ),
    const City(
      id: 'singapore',
      nameEn: 'Singapore',
      nameFa: 'سنگاپور',
      countryCode: 'SG',
      timezone: 'Asia/Singapore',
      latitude: 1.3521,
      longitude: 103.8198,
      flagEmoji: '🇸🇬',
    ),
    const City(
      id: 'mumbai',
      nameEn: 'Mumbai',
      nameFa: 'مومبای',
      countryCode: 'IN',
      timezone: 'Asia/Kolkata',
      latitude: 19.0760,
      longitude: 72.8777,
      flagEmoji: '🇮🇳',
    ),
    const City(
      id: 'moscow',
      nameEn: 'Moscow',
      nameFa: 'مسکو',
      countryCode: 'RU',
      timezone: 'Europe/Moscow',
      latitude: 55.7558,
      longitude: 37.6173,
      flagEmoji: '🇷🇺',
    ),
    const City(
      id: 'vancouver',
      nameEn: 'Vancouver',
      nameFa: 'ونکوور',
      countryCode: 'CA',
      timezone: 'America/Vancouver',
      latitude: 49.2827,
      longitude: -123.1207,
      flagEmoji: '🇨🇦',
    ),
    const City(
      id: 'melbourne',
      nameEn: 'Melbourne',
      nameFa: 'ملبورن',
      countryCode: 'AU',
      timezone: 'Australia/Melbourne',
      latitude: -37.8136,
      longitude: 144.9631,
      flagEmoji: '🇦🇺',
    ),
    const City(
      id: 'amsterdam',
      nameEn: 'Amsterdam',
      nameFa: 'آمستردام',
      countryCode: 'NL',
      timezone: 'Europe/Amsterdam',
      latitude: 52.3676,
      longitude: 4.9041,
      flagEmoji: '🇳🇱',
    ),
    const City(
      id: 'zurich',
      nameEn: 'Zurich',
      nameFa: 'زوریخ',
      countryCode: 'CH',
      timezone: 'Europe/Zurich',
      latitude: 47.3769,
      longitude: 8.5417,
      flagEmoji: '🇨🇭',
    ),
    const City(
      id: 'seoul',
      nameEn: 'Seoul',
      nameFa: 'سئول',
      countryCode: 'KR',
      timezone: 'Asia/Seoul',
      latitude: 37.5665,
      longitude: 126.9780,
      flagEmoji: '🇰🇷',
    ),
    const City(
      id: 'hong_kong',
      nameEn: 'Hong Kong',
      nameFa: 'هنگ کنگ',
      countryCode: 'HK',
      timezone: 'Asia/Hong_Kong',
      latitude: 22.3193,
      longitude: 114.1694,
      flagEmoji: '🇭🇰',
    ),
    const City(
      id: 'cairo',
      nameEn: 'Cairo',
      nameFa: 'قاهره',
      countryCode: 'EG',
      timezone: 'Africa/Cairo',
      latitude: 30.0444,
      longitude: 31.2357,
      flagEmoji: '🇪🇬',
    ),
    const City(
      id: 'rio',
      nameEn: 'Rio de Janeiro',
      nameFa: 'ریودوژانیرو',
      countryCode: 'BR',
      timezone: 'America/Sao_Paulo',
      latitude: -22.9068,
      longitude: -43.1729,
      flagEmoji: '🇧🇷',
    ),
  ];

  static City? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  static List<City> search(String query, {String languageCode = 'en'}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return all.where((c) {
      final name = languageCode == 'fa' ? c.nameFa : c.nameEn;
      return name.toLowerCase().contains(q) ||
          c.nameEn.toLowerCase().contains(q) ||
          c.nameFa.contains(q) ||
          c.countryCode.toLowerCase() == q ||
          c.timezone.toLowerCase().contains(q);
    }).toList();
  }

  /// Haversine nearest city for coordinate fallback when full boundary data
  /// is unavailable. Not a substitute for true timezone-boundary lookup.
  static City nearest(double latitude, double longitude) {
    City? best;
    var bestDist = double.infinity;
    for (final c in all) {
      final d = _haversineKm(latitude, longitude, c.latitude, c.longitude);
      if (d < bestDist) {
        bestDist = d;
        best = c;
      }
    }
    return best!;
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
    return r * c;
  }

  static double _rad(double deg) => deg * 3.141592653589793 / 180.0;
}
