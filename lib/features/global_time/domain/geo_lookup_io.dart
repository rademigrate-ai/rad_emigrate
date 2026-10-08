import 'package:timezone_finder/timezone_finder.dart' as tf;

String? lookupIanaTimezone({
  required double longitude,
  required double latitude,
}) {
  return tf.findLocation(longitude, latitude)?.name;
}
