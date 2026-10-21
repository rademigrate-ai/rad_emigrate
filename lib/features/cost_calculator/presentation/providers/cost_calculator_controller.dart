// Cost calculator providers.
//
// Pathways are derived from the verified visa catalog (the same source the
// visa pages use). No cost data is fetched from a bespoke endpoint and none is
// invented. When the catalog cannot load, the controller reports an explicit
// failure so the UI shows an honest unavailable state.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../visa/domain/entities/visa_entities.dart';
import '../../../visa/presentation/providers/visa_catalog_provider.dart';
import '../../domain/entities/immigration_cost.dart';
import '../../domain/fee_parsing.dart';

/// A pathway is only selectable when the catalog published fee text for it.
/// Otherwise it is still listed but flagged as having no verified figure.
List<CostPathway> pathwaysFromCatalog(VisaCatalog catalog) {
  final result = <CostPathway>[];
  for (final program in catalog.programs) {
    final country = catalog.countryById(program.countryId);
    final category = catalog.categoryById(program.categoryId);
    if (country == null || category == null) continue;
    result.add(
      CostPathway(
        id: program.id,
        countryId: country.id,
        countryName: country.name,
        flagEmoji: country.flagEmoji,
        categoryId: category.id,
        categoryName: category.name,
        title: program.title,
        feesText: program.fees ?? '',
        processingTime: program.processingTime,
        sourceTitle: program.source.title,
        sourcePublisher: program.source.publisher,
        sourceUrl: program.source.url,
        sourceRetrievedAt: program.source.retrievedAt,
      ),
    );
  }
  return result;
}

/// Locale-keyed list of selectable pathways.
final costPathwaysProvider = FutureProvider.family<List<CostPathway>, String>((
  ref,
  locale,
) async {
  final catalog = await ref
      .watch(visaRepositoryProvider)
      .loadCatalog(locale: locale);
  return pathwaysFromCatalog(catalog);
});

/// Currently selected pathway id.
final selectedPathwayIdProvider = StateProvider<String?>((_) => null);

/// Preferred display currency. Never triggers a conversion.
final displayCurrencyProvider = StateProvider<String>((_) => 'USD');

/// Breakdown for a selected pathway within a locale-keyed catalog.
///
/// The page passes the pathway id so the value stays correct across locale
/// changes and avoids a provider that guesses the locale.
CostBreakdown? breakdownFor(List<CostPathway> pathways, String? selectedId) {
  if (selectedId == null) return null;
  for (final pathway in pathways) {
    if (pathway.id == selectedId) return buildBreakdown(pathway);
  }
  return null;
}
