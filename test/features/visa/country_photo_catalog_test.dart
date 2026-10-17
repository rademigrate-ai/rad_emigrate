import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/visa/presentation/widgets/country_photo_catalog.dart';
import 'package:rad_emigrate/features/visa/presentation/widgets/country_photography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all approved mappings and ISO aliases survive the data migration', () {
    final data = jsonDecode(
      File('assets/images/destinations/catalog.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final assets = Directory(CountryPhotoCatalog.root)
        .listSync()
        .whereType<File>()
        .map((f) => f.path.replaceAll('\\', '/'))
        .toSet();
    final catalog = CountryPhotoCatalog(data: data, assets: assets);
    for (final code in (data['countries'] as Map).keys.cast<String>()) {
      expect(
        catalog.resolve(' ${code.toLowerCase()} '),
        endsWith('/${code.toLowerCase()}.jpg'),
      );
    }
    expect(catalog.resolve(' uk '), endsWith('/gb.jpg'));
    expect(catalog.resolve('ARE'), endsWith('/ae.jpg'));
    expect(catalog.resolve('NOR'), endsWith('/no.jpg'));
  });

  test(
    'new code and explicit destination image resolve without Flutter edits',
    () {
      final catalog = CountryPhotoCatalog(
        data: {
          'countries': {'PT': 'portugal-approved.webp'},
          'destinations': {'lisbon': 'lisbon-approved.jpg'},
        },
        assets: {
          '${CountryPhotoCatalog.root}/portugal-approved.webp',
          '${CountryPhotoCatalog.root}/lisbon-approved.jpg',
          '${CountryPhotoCatalog.root}/fi.jpg',
        },
      );
      expect(catalog.resolve('pt'), endsWith('/portugal-approved.webp'));
      expect(
        catalog.resolve('PT', destination: ' Lisbon '),
        endsWith('/lisbon-approved.jpg'),
      );
      expect(catalog.resolve('FI'), endsWith('/fi.jpg'));
      expect(catalog.resolve('ZZ'), CountryPhotoCatalog.fallback);
    },
  );

  test(
    'invalid, missing, remote and traversal values use the offline fallback',
    () {
      for (final value in [
        'https://unapproved.example/photo.jpg',
        '../secret.jpg',
        'missing.jpg',
        '',
        42,
      ]) {
        final catalog = CountryPhotoCatalog(
          data: {
            'countries': {'PT': value},
          },
          assets: {},
        );
        expect(catalog.resolve('PT'), CountryPhotoCatalog.fallback);
      }
      expect(
        CountryPhotoCatalog(data: {}, assets: {}).resolve('not a code'),
        CountryPhotoCatalog.fallback,
      );
    },
  );

  test(
    'catalog parse is shared and fails closed without a loader loop',
    () async {
      expect(
        identical(CountryPhotography.catalog, CountryPhotography.catalog),
        isTrue,
      );
      final first = await CountryPhotography.catalog;
      expect(identical(first, await CountryPhotography.catalog), isTrue);
      final unavailable = await CountryPhotoCatalog.load(_UnavailableBundle());
      expect(unavailable.resolve('CA'), CountryPhotoCatalog.fallback);
    },
  );

  testWidgets(
    'unknown destination paints a bundled fallback offline and reuses cache',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.square(
            dimension: 180,
            child: CountryPhotography.image(code: 'ZZ', fit: BoxFit.cover),
          ),
        ),
      );
      await tester.runAsync(() async {
        await CountryPhotography.catalog;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(
        (tester.widget<Image>(find.byType(Image)).image as AssetImage)
            .assetName,
        CountryPhotoCatalog.fallback,
      );
      final key = await const AssetImage(CountryPhotoCatalog.fallback)
          .obtainKey(const ImageConfiguration());
      final status = PaintingBinding.instance.imageCache.statusForKey(key);
      expect(status.pending || status.keepAlive || status.live, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

class _UnavailableBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw StateError('offline/missing');
}
