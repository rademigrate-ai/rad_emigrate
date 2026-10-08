import 'package:flutter/services.dart';
import 'package:timezone/browser.dart' as tz;
import 'package:timezone_finder/browser.dart' as tf;

/// Flutter Web: load latest_all tzf + install ODbL boundary polygons from assets.
///
/// Asset path must be declared in pubspec:
///   packages/timezone_finder/data/boundaries_2026c.bin
Future<void> bootstrapGeoTimezone() async {
  await tz.initializeTimeZone('packages/timezone/data/latest_all.tzf');
  final data = await rootBundle.load(
    'packages/timezone_finder/data/boundaries_2026c.bin',
  );
  tf.installBoundaries(data.buffer.asUint8List());
  await tf.ensurePreloaded();
}
