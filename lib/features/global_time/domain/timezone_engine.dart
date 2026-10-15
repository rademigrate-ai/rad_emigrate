import 'package:timezone/timezone.dart' as tz;

import 'city.dart';
import 'geo_bootstrap.dart';

/// Accurate IANA timezone conversions for RAD Global Time.
abstract final class TimezoneEngine {
  static bool _initialized = false;
  static Future<void>? _initialization;

  static bool get isReady => _initialized;

  /// Share a single bootstrap across concurrent callers. The timezone database
  /// must be ready before clock widgets attempt to resolve IANA locations.
  static Future<void> ensureInitialized() {
    if (_initialized) return Future<void>.value();
    return _initialization ??= _bootstrap();
  }

  static Future<void> _bootstrap() async {
    try {
      await bootstrapGeoTimezone();
      _initialized = true;
    } catch (_) {
      // Boundary polygons are optional. Clear the shared future so a later
      // caller can retry if the first attempt failed before markInitialized.
    } finally {
      _initialization = null;
    }
  }

  static void markInitialized() {
    _initialized = true;
  }

  static tz.Location locationOf(String ianaId) {
    try {
      return tz.getLocation(ianaId);
    } catch (_) {
      try {
        return tz.getLocation('UTC');
      } catch (_) {
        // Database not loaded yet — never rethrow into the widget tree.
        return tz.Location('UTC', [0], [0], [const tz.TimeZone.noDST(0)]);
      }
    }
  }

  static tz.TZDateTime nowIn(String ianaId) {
    final loc = locationOf(ianaId);
    return tz.TZDateTime.now(loc);
  }

  static tz.TZDateTime nowInCity(City city) => nowIn(city.timezone);

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
