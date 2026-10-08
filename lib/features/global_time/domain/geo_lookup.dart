import 'geo_lookup_stub.dart'
    if (dart.library.html) 'geo_lookup_web.dart'
    if (dart.library.io) 'geo_lookup_io.dart'
    as impl;

/// Returns IANA id for (longitude, latitude) or null if no land zone.
String? lookupIanaTimezone({
  required double longitude,
  required double latitude,
}) => impl.lookupIanaTimezone(longitude: longitude, latitude: latitude);
