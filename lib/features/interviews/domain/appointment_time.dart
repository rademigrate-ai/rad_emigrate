// Timezone-safe civil ↔ UTC conversion for appointment requests.
//
// Reuses the verified global_time TimezoneEngine (read-only import; that
// feature's files are not modified). All appointment instants are stored as
// UTC; civil entries are only interpreted inside the explicitly selected IANA
// zone, never implicitly in "whatever the device says".

import 'package:timezone/timezone.dart' as tz;

import '../../global_time/domain/timezone_engine.dart';

class CivilTimeInZone {
  const CivilTimeInZone({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.ianaZoneId,
  });

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final String ianaZoneId;

  /// True when this civil time does not exist in the zone (DST spring
  /// forward). The caller must ask the user to pick another time.
  bool get isDstGap => _candidates().isEmpty && TimezoneEngine.isReady;

  /// True when this civil time occurs twice (DST fall back).
  bool get isDstFold => _candidates().length > 1;

  /// UTC instant for the civil time.
  ///
  /// Returns null when the timezone database is unavailable (never guesses
  /// an offset) or when the time does not exist (DST gap).
  DateTime? toUtcOrNull() {
    if (!TimezoneEngine.isReady) return null;
    final matches = _candidates();
    if (matches.isEmpty) return null;
    // Fold: first occurrence is used; the UI surfaces the ambiguity.
    // TZDateTime fields are wall-clock in-zone — the epoch is the instant.
    final first = matches.first;
    return DateTime.fromMillisecondsSinceEpoch(
      first.millisecondsSinceEpoch,
      isUtc: true,
    );
  }

  List<DateTime> _candidates() {
    final date = DateTime(year, month, day);
    return TimezoneEngine.localCandidates(ianaZoneId, date, hour, minute);
  }
}

/// Display helpers for an appointment instant: always show the picked zone
/// alongside UTC so no ambiguity is hidden from the user.
class AppointmentTimeDisplay {
  const AppointmentTimeDisplay._();

  static String offsetLabel(String ianaZoneId, {DateTime? at}) {
    if (!TimezoneEngine.isReady) return '';
    return TimezoneEngine.offsetLabel(ianaZoneId, at: at);
  }

  /// Converts a stored UTC instant into the wall time of [ianaZoneId].
  ///
  /// Returns null when the zone cannot be resolved (TimezoneEngine falls
  /// back to UTC for unknown ids — that fallback must never be displayed as
  /// if it were the requested zone).
  static DateTime? inZone(DateTime utcInstant, String ianaZoneId) {
    if (!TimezoneEngine.isReady) return null;
    final loc = TimezoneEngine.locationOf(ianaZoneId);
    if (loc.name != ianaZoneId && ianaZoneId != 'UTC') return null;
    final zoned = tz.TZDateTime.from(utcInstant.toUtc(), loc);
    return DateTime(
      zoned.year,
      zoned.month,
      zoned.day,
      zoned.hour,
      zoned.minute,
    );
  }
}
