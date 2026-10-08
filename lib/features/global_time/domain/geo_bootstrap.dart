import 'geo_bootstrap_stub.dart'
    if (dart.library.html) 'geo_bootstrap_web.dart'
    if (dart.library.io) 'geo_bootstrap_io.dart'
    as impl;

/// Platform-specific timezone + boundary polygon initialization.
Future<void> bootstrapGeoTimezone() => impl.bootstrapGeoTimezone();
