import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:rad_emigrate/features/global_time/domain/timezone_engine.dart';
import 'package:rad_emigrate/features/global_time/domain/city_catalog.dart';
import 'package:rad_emigrate/features/global_time/domain/meeting_planner.dart';
import 'package:rad_emigrate/features/global_time/domain/solar_daylight.dart';
import 'package:rad_emigrate/features/global_time/data/favorites_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => TimezoneEngine.ensureInitialized());
  test(
    'concurrent timezone consumers share bootstrap, then clock zones resolve',
    () async {
      await Future.wait(
        List.generate(12, (_) => TimezoneEngine.ensureInitialized()),
      );
      expect(TimezoneEngine.isReady, isTrue);
      expect(
        TimezoneEngine.locationOf('America/Toronto').name,
        'America/Toronto',
      );
    },
  );
  test(
    'Toronto DST gap is rejected and repeated hour has two distinct instants',
    () {
      expect(
        TimezoneEngine.localCandidates(
          'America/Toronto',
          DateTime(2026, 3, 8),
          2,
          30,
        ),
        isEmpty,
      );
      final fold = TimezoneEngine.localCandidates(
        'America/Toronto',
        DateTime(2026, 11, 1),
        1,
        30,
      );
      expect(fold.length, 2);
      expect(fold[1].difference(fold[0]), const Duration(hours: 1));
      expect(fold.map((v) => v.timeZoneOffset.inHours), [-4, -5]);
    },
  );
  test(
    'half-hour DST transitions and date boundary conversions preserve instant',
    () {
      expect(
        TimezoneEngine.localCandidates(
          'Australia/Lord_Howe',
          DateTime(2026, 10, 4),
          2,
          15,
        ),
        isEmpty,
      );
      final source = TimezoneEngine.localCandidates(
        'Asia/Tokyo',
        DateTime(2026, 1, 1),
        0,
        30,
      ).single;
      final dest = tz.TZDateTime.from(
        source,
        TimezoneEngine.locationOf('America/Los_Angeles'),
      );
      expect(
        [dest.year, dest.month, dest.day, dest.hour, dest.minute],
        [2025, 12, 31, 7, 30],
      );
      expect(dest.toUtc(), source.toUtc());
    },
  );
  test(
    'modern Tehran has fixed +03:30, Toronto and Sydney follow seasonal DST',
    () {
      for (final month in [1, 7]) {
        expect(
          TimezoneEngine.offsetFromUtc(
            'Asia/Tehran',
            at: DateTime.utc(2026, month, 15),
          ),
          const Duration(minutes: 210),
        );
      }
      expect(
        TimezoneEngine.offsetFromUtc(
          'America/Toronto',
          at: DateTime.utc(2026, 1, 15),
        ),
        const Duration(hours: -5),
      );
      expect(
        TimezoneEngine.offsetFromUtc(
          'America/Toronto',
          at: DateTime.utc(2026, 7, 15),
        ),
        const Duration(hours: -4),
      );
      expect(
        TimezoneEngine.offsetFromUtc(
          'Australia/Sydney',
          at: DateTime.utc(2026, 1, 15),
        ),
        const Duration(hours: 11),
      );
      expect(
        TimezoneEngine.offsetFromUtc(
          'Australia/Sydney',
          at: DateTime.utc(2026, 7, 15),
        ),
        const Duration(hours: 10),
      );
    },
  );
  test(
    'meeting suggestions stay fully inside both documented working windows',
    () {
      final origin = CityCatalog.defaults[2], dest = CityCatalog.defaults[3];
      final windows = MeetingPlanner.suggestWindows(
        origin: origin,
        destination: dest,
        year: 2026,
        month: 3,
        day: 29,
        durationMinutes: 90,
      );
      expect(windows, isNotEmpty);
      for (final w in windows) {
        for (final pair in [
          (w.startLocalOrigin, w.endLocalOrigin),
          (w.startLocalDestination, w.endLocalDestination),
        ]) {
          expect(pair.$1.hour, greaterThanOrEqualTo(9));
          expect(
            pair.$2.hour * 60 + pair.$2.minute,
            lessThanOrEqualTo(18 * 60),
          );
          expect(pair.$2.difference(pair.$1), const Duration(minutes: 90));
          expect(pair.$1.day, pair.$2.day);
        }
        expect(w.startLocalOrigin.toUtc(), w.startLocalDestination.toUtc());
      }
    },
  );
  test('solar daylight handles real longitude and polar seasons', () {
    final tehran = CityCatalog.defaults.first;
    expect(SolarDaylight.at(tehran, DateTime.utc(2026, 6, 21, 9)), isTrue);
    expect(SolarDaylight.at(tehran, DateTime.utc(2026, 6, 21, 21)), isFalse);
    final pole = tehran.copyWith(latitude: 89, longitude: 0);
    expect(SolarDaylight.at(pole, DateTime.utc(2026, 6, 21)), isTrue);
    expect(SolarDaylight.at(pole, DateTime.utc(2026, 12, 21, 12)), isFalse);
  });
  test('favorites survive reconstruction with order, deletion and an intentionally empty list', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var repo = FavoritesRepository(prefs);
    await repo.save([CityCatalog.defaults[2], CityCatalog.defaults[0]]);
    repo = FavoritesRepository(prefs);
    expect(repo.load().map((c) => c.id), ['london', 'tehran']);
    await repo.remove('london');
    await repo.remove('tehran');
    expect(FavoritesRepository(prefs).load(), isEmpty);
    await repo.add(CityCatalog.defaults[4]);
    await repo.add(CityCatalog.defaults[4]);
    expect(FavoritesRepository(prefs).load().map((c) => c.id), ['dubai']);
  });
}
