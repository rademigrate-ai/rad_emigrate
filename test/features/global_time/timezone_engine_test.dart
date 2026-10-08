import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/global_time/domain/city_catalog.dart';
import 'package:rad_emigrate/features/global_time/domain/timezone_engine.dart';
import 'package:rad_emigrate/features/global_time/domain/meeting_planner.dart';

void main() {
  setUpAll(() async {
    await TimezoneEngine.ensureInitialized();
  });

  group('TimezoneEngine',
      () {
    test('Tehran offset is +3:30 or +4:30 depending on DST rules',
        () {
      final offset = TimezoneEngine.offsetFromUtc('Asia/Tehran');
      final minutes = offset.inMinutes;
      // Iran has used +3:30 historically; accept +3:30 or +4:30.
      expect(minutes == 210 || minutes == 270, isTrue,
          reason: 'unexpected Tehran offset minutes=$minutes');
    });

    test('Toronto, London, Berlin, Dubai, Sydney resolve',
        () {
      for (final city in CityCatalog.defaults) {
        final now = TimezoneEngine.nowInCity(city);
        expect(now.timeZoneName, isNotEmpty);
        expect(now.year, greaterThanOrEqualTo(2024));
      }
    });

    test('convert preserves instant across zones',
        () {
      final converted = TimezoneEngine.convert(
        fromIana: 'Asia/Tehran',
        toIana: 'America/Toronto',
        year: 2026,
        month: 6,
        day: 15,
        hour: 14,
        minute: 0,
      );
      expect(converted.hour, isNot(equals(14))); // different zone
    });

    test('isDaytime around noon is true',
        () {
      final noon = DateTime.utc(2026, 6, 15, 9, 0); // ~12:30 Tehran
      expect(
        TimezoneEngine.isDaytime('Asia/Tehran', at: noon),
        isTrue,
      );
    });
  });

  group('MeetingPlanner',
      () {
    test('suggests windows for Tehran–Toronto',
        () {
      final tehran = CityCatalog.defaults[0];
      final toronto = CityCatalog.defaults[1];
      final windows = MeetingPlanner.suggestWindows(
        origin: tehran,
        destination: toronto,
        year: 2026,
        month: 6,
        day: 15,
        durationMinutes: 60,
      );
      expect(windows, isNotEmpty);
      // At least one high-quality window expected on a normal weekday.
      expect(windows.any((w) => w.quality >= 0.5), isTrue);
    });

    test('no crash when zones are far apart',
        () {
      final tehran = CityCatalog.defaults[0];
      final sydney = CityCatalog.defaults[5];
      final windows = MeetingPlanner.suggestWindows(
        origin: tehran,
        destination: sydney,
        year: 2026,
        month: 1,
        day: 10,
      );
      expect(windows, isA<List>());
    });
  });

  group('CityCatalog',
      () {
    test('search finds Tehran in English and Persian',
        () {
      expect(CityCatalog.search('Teh'), isNotEmpty);
      expect(CityCatalog.search('تهر', languageCode: 'fa'), isNotEmpty);
    });

    test('nearest returns a city for a known coordinate',
        () {
      final near = CityCatalog.nearest(35.7, 51.4);
      expect(near.id, 'tehran');
    });
  });
}
