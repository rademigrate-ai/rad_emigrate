import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone_finder/timezone_finder.dart' as tf;

import 'timezone_engine.dart';

/// Native / VM / mobile / desktop: boundaries are compiled into timezone_finder.
Future<void> bootstrapGeoTimezone() async {
  await bootstrapTimezoneDatabase();
  await tf.ensurePreloaded();
}

Future<void> bootstrapTimezoneDatabase() async {
  if (TimezoneEngine.isReady) return;
  tz_data.initializeTimeZones();
  TimezoneEngine.markInitialized();
}
