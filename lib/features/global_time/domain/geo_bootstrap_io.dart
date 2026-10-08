import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone_finder/timezone_finder.dart' as tf;

import 'timezone_engine.dart';

/// Native / VM / mobile / desktop: boundaries are compiled into timezone_finder.
Future<void> bootstrapGeoTimezone() async {
  tz_data.initializeTimeZones();
  await tf.ensurePreloaded();
  TimezoneEngine.markInitialized();
}
