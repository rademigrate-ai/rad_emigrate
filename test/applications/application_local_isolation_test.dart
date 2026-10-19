import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/features/applications/data/datasources/application_local_datasource.dart';
import 'package:rad_emigrate/features/applications/domain/entities/application_status.dart';
import 'package:rad_emigrate/features/applications/domain/entities/visa_application.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  VisaApplication app(String id, String userId) => VisaApplication(
    id: id,
    userId: userId,
    title: 'T',
    programName: 'P',
    country: 'CA',
    status: ApplicationStatus.draft,
    updatedAt: DateTime.utc(2026, 10, 18),
  );

  group('ApplicationLocalDataSource user isolation', () {
    test('user A cache does not contain user B rows', () async {
      final prefs = await SharedPreferences.getInstance();
      final ds = ApplicationLocalDataSource(prefs);

      await ds.writeForUser('user-a', [app('1', 'user-a')]);
      await ds.writeForUser('user-b', [app('2', 'user-b')]);

      final a = await ds.readForUser('user-a');
      final b = await ds.readForUser('user-b');
      expect(a.map((e) => e.id), ['1']);
      expect(b.map((e) => e.id), ['2']);
    });

    test('writeForUser strips foreign-owned rows', () async {
      final prefs = await SharedPreferences.getInstance();
      final ds = ApplicationLocalDataSource(prefs);
      await ds.writeForUser('user-a', [
        app('1', 'user-a'),
        app('2', 'user-b'), // foreign — must not persist under user-a
      ]);
      final a = await ds.readForUser('user-a');
      expect(a.map((e) => e.id), ['1']);
    });

    test('clearForUser leaves other users', () async {
      final prefs = await SharedPreferences.getInstance();
      final ds = ApplicationLocalDataSource(prefs);
      await ds.writeForUser('user-a', [app('1', 'user-a')]);
      await ds.writeForUser('user-b', [app('2', 'user-b')]);
      await ds.clearForUser('user-a');
      expect(await ds.readForUser('user-a'), isEmpty);
      expect((await ds.readForUser('user-b')).length, 1);
    });

    test('corrupted scoped payload fails closed to empty', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rad_applications_user-x', '[[[bad');
      final ds = ApplicationLocalDataSource(prefs);
      expect(await ds.readForUser('user-x'), isEmpty);
    });

    test('empty userId writeForUser throws', () async {
      final prefs = await SharedPreferences.getInstance();
      final ds = ApplicationLocalDataSource(prefs);
      expect(
        () => ds.writeForUser('', [app('1', 'x')]),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
