import 'package:timezone/data/latest_all.dart' as tz_data;

Future<void> bootstrapGeoTimezone() async {
  tz_data.initializeTimeZones();
}
