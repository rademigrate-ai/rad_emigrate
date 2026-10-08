import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'city.dart';

/// Accurate IANA timezone conversions for RAD Global Time.
///
/// Uses `latest_all` so link identifiers required by timezone_finder boundaries
/// are present.
abstract final class TimezoneEngine {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _initialized = true;
  }

  static tz.Location locationOf(String ianaId) {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _initialized = true;
    }
    try {
      return tz.getLocation(ianaId);
    } catch (_) {
      return tz.getLocation('UTC');
    }
  }

  static tz.TZDateTime nowIn(String ianaId) {
    final loc = locationOf(ianaId);
    return tz.TZDateTime.now(loc);
  }

  static tz.TZDateTime nowInCity(City city) => nowIn(city.timezone);

  /// Convert a civil time in [fromIana] to the equivalent instant in [toIana].
  /// Uses timezone package rules; ambiguous/nonexistent local times follow
  /// package defaults (typically the earlier offset / skip forward).
  static tz.TZDateTime convert({
    required String fromIana,
    required String toIana,
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
  }) {
    final from = locationOf(fromIana);
    final to = locationOf(toIana);
    final local = tz.TZDateTime(from, year, month, day, hour, minute);
    return tz.TZDateTime.from(local, to);
  }

  static Duration offsetFromUtc(String ianaId, {DateTime? at}) {
    final loc = locationOf(ianaId);
    final instant = at != null
        ? tz.TZDateTime.from(at.toUtc(), loc)
        : tz.TZDateTime.now(loc);
    return instant.timeZoneOffset;
  }

  static String offsetLabel(String ianaId, {DateTime? at}) {
    final offset = offsetFromUtc(ianaId, at: at);
    final totalMinutes = offset.inMinutes;
    final sign = totalMinutes >= 0 ? '+' : '-';
    final abs = totalMinutes.abs();
    final h = abs ~/ 60;
    final m = abs % 60;
    if (m == 0) return 'GMT$sign$h';
    return 'GMT$sign$h:${m.toString().padLeft(2, '0')}';
  }

  static bool isDaytime(String ianaId, {DateTime? at}) {
    final now = at != null
        ? tz.TZDateTime.from(at.toUtc(), locationOf(ianaId))
        : nowIn(ianaId);
    final hour = now.hour;
    return hour >= 6 && hour < 20;
  }
}
