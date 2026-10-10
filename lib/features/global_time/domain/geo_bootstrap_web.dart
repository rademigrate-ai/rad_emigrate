import 'package:flutter/services.dart';
import 'package:timezone/browser.dart' as tz;
import 'package:timezone_finder/browser.dart' as tf;

import 'timezone_engine.dart';

/// Flutter Web: load latest_all tzf + install ODbL boundary polygons from assets.
Future<void> bootstrapGeoTimezone() async {
  // timezone/browser fetches with HTTP rather than Flutter's AssetBundle, so
  // packaged assets must use their emitted web path under /assets. Using the
  // logical pubspec key here returns the SPA index.html and leaves tzdata
  // uninitialized.
  await tz.initializeTimeZone('assets/packages/timezone/data/latest_all.tzf');
  // The timezone database is essential; map polygons are optional. Mark
  // clocks ready before attempting the larger boundary asset download.
  TimezoneEngine.markInitialized();
  final data = await rootBundle.load(
    'packages/timezone_finder/data/boundaries_2026c.bin',
  );
  tf.installBoundaries(data.buffer.asUint8List());
  await tf.ensurePreloaded();
}
