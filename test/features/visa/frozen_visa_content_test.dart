import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/visa/data/frozen_visa_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled Visa snapshot is immutable, holds-free and country complete',
    () async {
      final index = jsonDecode(
        await rootBundle.loadString('assets/visa_frozen_content/index.json'),
      ) as Map<String, dynamic>;
      expect(index['format'], 'RAD_FROZEN_VISA_DELIVERY_V1');
      expect(index['total_candidates'], 1077);
      expect(index['held_excluded'], 23);
      expect(index['editorial_approved'], false);
      expect(index['update_mode'], 'read_only');
      expect((index['articles'] as List).length, 1077);
      final snapshot = FrozenVisaContent();
      final faCountries = await snapshot.countries('fa');
      final enCountries = await snapshot.countries('en');
      expect(faCountries.length, 56);
      expect(enCountries.length, 56);
      expect(
        faCountries.map((c) => c['country_code']).toSet(),
        enCountries.map((c) => c['country_code']).toSet(),
      );

      final faLibrary = await snapshot.library('fa', null);
      expect((faLibrary['items'] as List).length, 20);
      expect(faLibrary['has_more'], true);
      final page2 = await snapshot.library(
        'fa',
        faLibrary['next_cursor'] as String,
      );
      expect(
        (faLibrary['items'] as List).first['id'],
        isNot((page2['items'] as List).first['id']),
      );
      final item = (faLibrary['items'] as List).first as Map;
      final article = await snapshot.article(
        item['id'] as String,
        item['locale'] as String,
      );
      expect(article['id'], item['id']);
      expect(article['delivery_mode'], 'frozen_source_readonly');
      expect(article['editorial_approved'], false);
      expect(article['verification_state'], 'unverified');
      expect(article['rich_sections'], isNotEmpty);
      expect(article['sources'], isNotEmpty);
      expect(article['source_policy'], 'RAD_CONTENT_PRECEDENCE_V4.1');
    },
  );

  test(
    'reader never invents a translation and rejects invalid identities',
    () async {
      final snapshot = FrozenVisaContent();
      final library = await snapshot.library('en', null);
      final item = (library['items'] as List).first as Map;
      final article = await snapshot.article(item['id'] as String, 'en');
      expect(article['locale'], item['locale']);
      if (item['locale'] != 'en') {
        expect(article['requested_locale_fallback'], 'en');
      }
      await expectLater(
        snapshot.article('../private', 'fa'),
        throwsFormatException,
      );
      await expectLater(snapshot.country('../', 'fa'), throwsFormatException);
      await expectLater(snapshot.library('fa', '-1'), throwsFormatException);
    },
  );

  test(
    'employer review catalog searches the same immutable snapshot',
    () async {
      final snapshot = FrozenVisaContent();
      final all = await snapshot.reviewCatalog('fa');
      expect(all['read_only'], true);
      expect(all['editorial_approved'], false);
      expect(all['total'], greaterThan(1000));
      expect((all['items'] as List).length, 24);
      final next = await snapshot.reviewCatalog(
        'fa',
        cursor: all['next_cursor'] as String,
      );
      expect(
        (all['items'] as List).first['id'],
        isNot((next['items'] as List).first['id']),
      );

      final ae = await snapshot.reviewCatalog('fa', countryCode: 'AE');
      expect(ae['total'], greaterThan(0));
      for (final row in (ae['items'] as List).whereType<Map>()) {
        expect((row['country_codes'] as List), contains('AE'));
      }
      final first = (all['items'] as List).first as Map;
      final found = await snapshot.reviewCatalog(
        'fa',
        search: first['id'] as String,
      );
      expect(found['total'], 1);
      expect((found['items'] as List).first['id'], first['id']);
      await expectLater(
        snapshot.reviewCatalog('fa', countryCode: '../'),
        throwsFormatException,
      );
      await expectLater(
        snapshot.reviewCatalog('fa', cursor: '-1'),
        throwsFormatException,
      );
    },
  );
}
