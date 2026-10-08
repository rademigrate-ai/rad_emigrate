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
      expect(converted.hour, isNot(equals(14)));
    });

    test('isDaytime around noon is true',
        () {
      final noon = DateTime.utc(2026, 6, 15, 9, 0);
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

    test('DST spring-forward date still returns list',
        () {
      // US spring forward 2026-03-08 — planner must not throw.
      final toronto = CityCatalog.defaults[1];
      final london = CityCatalog.defaults[2];
      final windows = MeetingPlanner.suggestWindows(
        origin: toronto,
        destination: london,
        year: 2026,
        month: 3,
        day: 8,
        durationMinutes: 60,
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
