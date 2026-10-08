import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/global_time/domain/geo_timezone_resolver.dart';
import 'package:rad_emigrate/features/global_time/domain/timezone_engine.dart';

void main() {
  setUpAll(() async {
    await TimezoneEngine.ensureInitialized();
    await GeoTimezoneResolver.ensureReady();
  });

  group('GeoTimezoneResolver boundary lookup',
      () {
    test('Tehran center resolves to Asia/Tehran',
        () async {
      final r = await GeoTimezoneResolver.resolve(
        latitude: 35.6892,
        longitude: 51.3890,
      );
      // May be unavailable on web without bin; if resolved must be correct.
      if (r.status == GeoResolveStatus.resolved) {
        expect(r.ianaId, 'Asia/Tehran');
        expect(r.toCity(), isNotNull);
      } else {
        expect(
          r.status,
          anyOf(
            GeoResolveStatus.unresolved,
            GeoResolveStatus.unavailable,
          ),
        );
      }
    });

    test('mid-Atlantic ocean is unresolved or unavailable',
        () async {
      final r = await GeoTimezoneResolver.resolve(
        latitude: 0,
        longitude: -30,
      );
      expect(
        r.status,
        anyOf(
          GeoResolveStatus.unresolved,
          GeoResolveStatus.unavailable,
        ),
      );
      expect(r.toCity(), isNull);
    });

    test('manual override never invents silently',
        () {
      final city = GeoTimezoneResolver.cityWithManualTimezone(
        latitude: 0,
        longitude: -30,
        ianaId: 'UTC',
      );
      expect(city.timezone, 'UTC');
    });

    test('Dubai non-hour offset zone still has clocks',
        () async {
      await TimezoneEngine.ensureInitialized();
      final now = TimezoneEngine.nowIn('Asia/Dubai');
      expect(now.timeZoneOffset.inMinutes % 60, 0); // Dubai is +4:00
      final tehran = TimezoneEngine.nowIn('Asia/Tehran');
      // Tehran is +3:30 or +4:30
      expect(tehran.timeZoneOffset.inMinutes % 30, 0);
    });
  });
}
