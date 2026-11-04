import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/supabase/supabase_providers.dart';
import 'package:rad_emigrate/features/visa/data/editorial_repository.dart';
import 'package:rad_emigrate/features/visa/data/frozen_visa_content.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/mock_supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'missing Production public RPCs read full immutable Visa snapshot',
    () async {
      final paths = <String>[];
      final service = await mockSupabaseService((request) async {
        paths.add(request.url.path);
        return rpcJson({
          'code': 'PGRST202',
          'message': 'The function is missing from the public schema cache.',
        }, 404);
      });
      final container = ProviderContainer(
        overrides: [supabaseClientServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      container.listen(visaContentCountriesProvider('fa'), (_, _) {});
      final countries = await container.read(
        visaContentCountriesProvider('fa').future,
      );
      expect(countries.length, 56);
      container.listen(
        countryVisaContentProvider((
          country: 'AE',
          locale: 'fa',
          preview: false,
        )),
        (_, _) {},
      );
      final ae = await container.read(
        countryVisaContentProvider((
          country: 'AE',
          locale: 'fa',
          preview: false,
        )).future,
      );
      expect(ae['delivery_mode'], 'frozen_source_readonly');
      expect(
        (ae['categories'] as List).length + (ae['other_titles'] as List).length,
        greaterThan(0),
      );
      container.listen(
        otherTitlesLibraryProvider((
          locale: 'fa',
          preview: false,
          cursor: null,
        )),
        (_, _) {},
      );
      final library = await container.read(
        otherTitlesLibraryProvider((locale: 'fa', preview: false, cursor: null))
            .future,
      );
      expect(library['delivery_mode'], 'frozen_source_readonly');
      expect((library['items'] as List).length, 20);
      final entry = await frozenVisaContent.reviewCatalog('fa', limit: 1);
      final row = (entry['items'] as List).first as Map;
      container.listen(
        editorialArticleProvider((
          id: row['id'] as String,
          locale: row['locale'] as String,
          preview: false,
        )),
        (_, _) {},
      );
      final article = await container.read(
        editorialArticleProvider((
          id: row['id'] as String,
          locale: row['locale'] as String,
          preview: false,
        )).future,
      );
      expect(article['id'], row['id']);
      expect(article['editorial_approved'], false);
      expect(article['rich_sections'], isNotEmpty);
      expect(
        paths
            .where((path) => path.endsWith('/rpc/list_country_visa_content'))
            .length,
        1,
      );
      expect(
        paths.any((path) => path.endsWith('/rpc/list_visa_content_countries')),
        true,
      );
      expect(
        paths.any((path) => path.endsWith('/rpc/get_editorial_article')),
        true,
      );
      expect(
        paths.any((path) => path.endsWith('/rpc/list_editorial_library')),
        true,
      );
    },
  );

  test('403 cannot be turned into a static public CMS bypass', () async {
    final paths = <String>[];
    final service = await mockSupabaseService((request) async {
      paths.add(request.url.path);
      return rpcJson({
        'code': '42501',
        'message': 'permission denied for relation',
      }, 403);
    });
    final container = ProviderContainer(
      overrides: [supabaseClientServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.listen(visaContentCountriesProvider('fa'), (_, _) {});
    container.listen(
      countryVisaContentProvider((country: 'AE', locale: 'fa', preview: false)),
      (_, _) {},
    );
    await expectLater(
      container.read(visaContentCountriesProvider('fa').future),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      container.read(
        countryVisaContentProvider((
          country: 'AE',
          locale: 'fa',
          preview: false,
        )).future,
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(paths.length, greaterThanOrEqualTo(2));
  });

  test('preview requires server auth even when RPC is missing', () async {
    final service = await mockSupabaseService(
      (request) async =>
          rpcJson({'code': 'PGRST202', 'message': 'Not present'}, 404),
    );
    final container = ProviderContainer(
      overrides: [supabaseClientServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.listen(visaContentPreviewCountriesProvider('fa'), (_, _) {});
    await expectLater(
      container.read(visaContentPreviewCountriesProvider('fa').future),
      throwsA(isA<PostgrestException>()),
    );
  });

  test(
    'malformed CMS response fails closed rather than showing the snapshot',
    () async {
      final service = await mockSupabaseService(
        (request) async => rpcJson({'data': <String, dynamic>{}}),
      );
      final container = ProviderContainer(
        overrides: [supabaseClientServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      container.listen(visaContentCountriesProvider('fa'), (_, _) {});
      await expectLater(
        container.read(visaContentCountriesProvider('fa').future),
        throwsFormatException,
      );
    },
  );
}
