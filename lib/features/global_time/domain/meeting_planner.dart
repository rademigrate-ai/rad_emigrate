import 'package:timezone/timezone.dart' as tz;

import 'city.dart';
import 'timezone_engine.dart';

/// Suggested overlapping working-hour windows (not confirmed availability).
class MeetingWindow {
  const MeetingWindow({
    required this.startLocalOrigin,
    required this.endLocalOrigin,
    required this.startLocalDestination,
    required this.endLocalDestination,
    required this.quality,
  });

  final tz.TZDateTime startLocalOrigin;
  final tz.TZDateTime endLocalOrigin;
  final tz.TZDateTime startLocalDestination;
  final tz.TZDateTime endLocalDestination;

  /// 0 = least suitable, 1 = ideal overlap within preferred hours.
  final double quality;
}

abstract final class MeetingPlanner {
  /// Default preferred working hours (local) for overlap suggestions.
  static const int defaultWorkStartHour = 9;
  static const int defaultWorkEndHour = 18;

  /// Compute suggested meeting windows between [origin] and [destination]
  /// on the given civil date in the origin timezone.
  ///
  /// Results are labelled as suggested overlapping working-hour windows only.
  static List<MeetingWindow> suggestWindows({
    required City origin,
    required City destination,
    required int year,
    required int month,
    required int day,
    int durationMinutes = 60,
    int workStartHour = defaultWorkStartHour,
    int workEndHour = defaultWorkEndHour,
  }) {
    TimezoneEngine.ensureInitialized();
    final originLoc = TimezoneEngine.locationOf(origin.timezone);
    final destLoc = TimezoneEngine.locationOf(destination.timezone);

    final windows = <MeetingWindow>[];

    // Slide candidate start times in origin local time across the day.
    for (var hour = 0; hour < 24; hour++) {
      for (var minute = 0; minute < 60; minute += 30) {
        final startOrigin =
            tz.TZDateTime(originLoc, year, month, day, hour, minute);
        final endOrigin = startOrigin.add(Duration(minutes: durationMinutes));

        // Skip if end spills past midnight of the chosen day in origin.
        if (endOrigin.day != day && endOrigin.hour > 0) continue;

        final startDest = tz.TZDateTime.from(startOrigin, destLoc);
        final endDest = tz.TZDateTime.from(endOrigin, destLoc);

        final originOk = _withinWorkHours(
          startOrigin,
          endOrigin,
          workStartHour,
          workEndHour,
        );
        final destOk = _withinWorkHours(
          startDest,
          endDest,
          workStartHour,
          workEndHour,
        );

        if (!originOk && !destOk) continue;

        double quality = 0;
        if (originOk && destOk) {
          quality = 1.0;
        } else if (originOk || destOk) {
          quality = 0.55;
        }

        // Prefer mid-morning / early-afternoon slots slightly.
        final midHour = hour + minute / 60.0;
        if (midHour >= 10 && midHour <= 15) quality += 0.1;
        quality = quality.clamp(0.0, 1.0);

        windows.add(
          MeetingWindow(
            startLocalOrigin: startOrigin,
            endLocalOrigin: endOrigin,
            startLocalDestination: startDest,
            endLocalDestination: endDest,
            quality: quality,
          ),
        );
      }
    }

    windows.sort((a, b) => b.quality.compareTo(a.quality));

    // Deduplicate overlapping suggestions: keep top distinct start hours.
    final result = <MeetingWindow>[];
    final seenHours = <int>{};
    for (final w in windows) {
      final key = w.startLocalOrigin.hour;
      if (seenHours.contains(key)) continue;
      seenHours.add(key);
      result.add(w);
      if (result.length >= 6) break;
    }
    return result;
  }

  static bool _withinWorkHours(
    tz.TZDateTime start,
    tz.TZDateTime end,
    int workStart,
    int workEnd,
  ) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    final workStartM = workStart * 60;
    final workEndM = workEnd * 60;
    // Simple same-day check; if end wraps past midnight treat as outside.
    if (end.day != start.day) return false;
    return startMinutes >= workStartM && endMinutes <= workEndM;
  }
}
