// Comparison providers.
//
// Entries are derived from the verified visa catalog. Selection is held in
// Riverpod state so the comparison grid is deep-linkable and testable without
// bespoke networking. No data is fabricated when the catalog is unavailable.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../visa/presentation/providers/visa_catalog_provider.dart';
import '../../domain/entities/pathway_comparison.dart';

/// Locale-keyed comparison entries built from the verified catalog.
final comparisonEntriesProvider =
    FutureProvider.family<List<ComparisonEntry>, String>((ref, locale) async {
      final catalog = await ref
          .watch(visaRepositoryProvider)
          .loadCatalog(locale: locale);
      final countries = {for (final c in catalog.countries) c.id: c};
      final categories = {for (final c in catalog.categories) c.id: c};

      final programs = <VisaProgramLike>[];
      for (final program in catalog.programs) {
        final country = countries[program.countryId];
        final category = categories[program.categoryId];
        if (country == null || category == null) continue;
        programs.add(
          VisaProgramLike(
            id: program.id,
            countryName: country.name,
            flagEmoji: country.flagEmoji,
            title: program.title,
            categoryName: category.name,
            processingTime: program.processingTime,
            fees: program.fees,
            requirements: program.requirements
                .map((r) => r.text)
                .toList(growable: false),
            sourceTitle: program.source.title,
            sourcePublisher: program.source.publisher,
            sourceUrl: program.source.url,
            sourceRetrievedAt: program.source.retrievedAt,
          ),
        );
      }
      return entriesFromPrograms(programs);
    });

/// Ids of the pathways currently selected for comparison.
final selectedComparisonIdsProvider = StateProvider<List<String>>(
  (_) => const [],
);

/// Toggles an entry in the selection set (max of [maxCompare] enforced).
const int kMaxCompare = 3;

void toggleComparison(WidgetRef ref, String id) {
  final current = ref.read(selectedComparisonIdsProvider);
  if (current.contains(id)) {
    ref.read(selectedComparisonIdsProvider.notifier).state = current
        .where((e) => e != id)
        .toList(growable: false);
    return;
  }
  if (current.length >= kMaxCompare) return;
  ref.read(selectedComparisonIdsProvider.notifier).state = [...current, id];
}
