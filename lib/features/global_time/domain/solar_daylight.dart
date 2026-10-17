import 'dart:math' as math;

import 'city.dart';

/// NOAA fractional-year solar-position approximation. Daylight includes the
/// standard -0.833 degree sunrise/refraction threshold; not a weather feed.
/// https://gml.noaa.gov/grad/solcalc/solareqns.PDF
abstract final class SolarDaylight {
  static bool at(City city, DateTime instant) {
    final utc = instant.toUtc();
    final day = utc.difference(DateTime.utc(utc.year)).inDays + 1;
    final days = DateTime.utc(utc.year + 1)
        .difference(DateTime.utc(utc.year))
        .inDays;
    final gamma =
        2 * math.pi / days * (day - 1 + (utc.hour + utc.minute / 60 - 12) / 24);
    final equation =
        229.18 *
        (0.000075 +
            0.001868 * math.cos(gamma) -
            0.032077 * math.sin(gamma) -
            0.014615 * math.cos(2 * gamma) -
            0.040849 * math.sin(2 * gamma));
    final declination =
        0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma) -
        0.002697 * math.cos(3 * gamma) +
        0.00148 * math.sin(3 * gamma);
    final solarMinute =
        (utc.hour * 60 + utc.minute + equation + 4 * city.longitude) % 1440;
    final angle = (solarMinute / 4 - 180) * math.pi / 180;
    final latitude = city.latitude * math.pi / 180;
    final elevation = math.asin(
      (math.sin(latitude) * math.sin(declination) +
              math.cos(latitude) * math.cos(declination) * math.cos(angle))
          .clamp(-1.0, 1.0),
    );
    return elevation >= -0.833 * math.pi / 180;
  }
}
