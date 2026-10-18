import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/features/profile/data/datasources/immigration_profile_local_datasource.dart';
import 'package:rad_emigrate/features/profile/data/repositories/immigration_profile_repository_impl.dart';
import 'package:rad_emigrate/features/profile/domain/entities/profile_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('ImmigrationProfileLocalDataSource isolation', () {
    test('user A cannot read user B draft', () async {
      final prefs = await SharedPreferences.getInstance();
      final ds = ImmigrationProfileLocalDataSource(prefs);

      await ds.write(
        'user-a',
        const ImmigrationProfile(fullName: 'Alice', nationality: 'IR'),
      );
      await ds.write(
        'user-b',
        const ImmigrationProfile(fullName: 'Bob', nationality: 'CA'),
      );

      final a = await ds.read('user-a');
      final b = await ds.read('user-b');
      expect(a?.fullName, 'Alice');
      expect(b?.fullName, 'Bob');
      expect(a?.fullName, isNot(b?.fullName));
    });

    test('clear user A leaves user B intact', () async {
      final prefs = await SharedPreferences.getInstance();
      final ds = ImmigrationProfileLocalDataSource(prefs);
      await ds.write('user-a', const ImmigrationProfile(fullName: 'Alice'));
      await ds.write('user-b', const ImmigrationProfile(fullName: 'Bob'));

      await ds.clear('user-a');
      expect(await ds.read('user-a'), isNull);
      expect((await ds.read('user-b'))?.fullName, 'Bob');
    });

    test('corrupted payload fails closed to null', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rad_immigration_profile_user-x', '{not-json');
      final ds = ImmigrationProfileLocalDataSource(prefs);
      expect(await ds.read('user-x'), isNull);
    });

    test('empty userId write throws; read returns null', () async {
      final prefs = await SharedPreferences.getInstance();
      final ds = ImmigrationProfileLocalDataSource(prefs);
      expect(
        () => ds.write('', const ImmigrationProfile(fullName: 'X')),
        throwsA(isA<ArgumentError>()),
      );
      expect(await ds.read(''), isNull);
    });

    test('repository clearLocalDraft removes draft', () async {
      final prefs = await SharedPreferences.getInstance();
      final ds = ImmigrationProfileLocalDataSource(prefs);
      final repo = ImmigrationProfileRepositoryImpl(local: ds);
      await repo.saveImmigrationProfile(
        'user-a',
        const ImmigrationProfile(fullName: 'Alice'),
      );
      expect(await repo.getImmigrationProfile('user-a'), isNotNull);
      await repo.clearLocalDraft('user-a');
      expect(await repo.getImmigrationProfile('user-a'), isNull);
    });

    test('clearAllImmigrationDrafts removes all keys', () async {
      final prefs = await SharedPreferences.getInstance();
      final ds = ImmigrationProfileLocalDataSource(prefs);
      await ds.write('a', const ImmigrationProfile(fullName: 'A'));
      await ds.write('b', const ImmigrationProfile(fullName: 'B'));
      final n = await ds.clearAllImmigrationDrafts();
      expect(n, greaterThanOrEqualTo(2));
      expect(await ds.read('a'), isNull);
      expect(await ds.read('b'), isNull);
    });
  });
}
