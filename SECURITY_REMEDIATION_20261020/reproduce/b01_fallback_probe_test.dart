import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/supabase/supabase_client.dart';
import 'package:rad_emigrate/features/visa/data/canonical_pathway_repository.dart';
import 'package:rad_emigrate/features/visa/data/fx_repository.dart';
import 'package:rad_emigrate/features/visa/data/visa_search_repository.dart';
import 'package:rad_emigrate/features/visa/domain/entities/search_entities.dart';
import 'package:rad_emigrate/features/visa/domain/entities/fx_rate.dart';

// Independent expectations, no network or immigration claims. The search call
// follows b01f625's renamed interface; assertions retain the original meaning.
void main() {
  final service = SupabaseClientService.instance;
  test('unavailable FX must not fabricate a fresh provider observation', () async {
    expect(service.isInitialized, isFalse);
    await expectLater(
      SupabaseFxRepository(service).getQuote(),
      throwsA(anything),
    );
  });
  test('unavailable canonical content must not report verified evidence', () async {
    final article = await SupabaseCanonicalPathwayRepository(service)
        .getCanonicalPathway(countryCode: 'de', pathwaySlug: 'chancenkarte');
    expect(article?.factualStatus, isNot(FactualStatus.verified));
  });
  test('unavailable search must not return verified fixture hits', () async {
    final result = await SupabaseVisaSearchRepository(service)
        .search(query: 'chancenkarte');
    expect(
      result.hits.any((hit) => hit.factualStatus == FactualStatus.verified),
      isFalse,
    );
  });
  test('malformed FX decoder must not fabricate freshness', () {
    expect(() => FxRateQuote.fromJson({}), throwsA(anything));
  });
}
