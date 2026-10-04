import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/visa_entities.dart';
import '../providers/visa_catalog_provider.dart';

class VisaPage extends ConsumerStatefulWidget {
  const VisaPage({super.key});

  @override
  ConsumerState<VisaPage> createState() => _VisaPageState();
}

class _VisaPageState extends ConsumerState<VisaPage> {
  String? _countryId;
  String? _categoryId;
  String _query = '';
  VisaProgram? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final catalog = ref.watch(visaCatalogProvider(locale));
    if (_selected != null) {
      return catalog.maybeWhen(
        data: (value) => _ProgramDetail(
          program: _selected!,
          country: value.countries.firstWhere(
            (item) => item.id == _selected!.countryId,
          ),
          onBack: () => setState(() => _selected = null),
        ),
        orElse: () => const SizedBox.shrink(),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.visaPathways),
      ),
      body: catalog.when(
        loading: () => LoadingState(message: l10n.loadingCatalogue),
        error: (error, _) => ErrorState(
          message: l10n.catalogueUnavailable,
          onRetry: () => ref.invalidate(visaCatalogProvider(locale)),
        ),
        data: (value) => _catalog(context, value, l10n),
      ),
    );
  }

  Widget _catalog(
    BuildContext context,
    VisaCatalog catalog,
    AppLocalizations l10n,
  ) {
    final query = _query.trim().toLowerCase();
    final programs = catalog.programs.where((program) {
      return (_countryId == null || program.countryId == _countryId) &&
          (_categoryId == null || program.categoryId == _categoryId) &&
          (query.isEmpty ||
              program.title.toLowerCase().contains(query) ||
              program.summary.toLowerCase().contains(query));
    }).toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              l10n.findPathway,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(l10n.catalogueDisclaimer),
            const SizedBox(height: 20),
            SearchBar(
              hintText: l10n.searchProgrammes,
              leading: const Icon(Icons.search),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(l10n.allDestinations),
                  selected: _countryId == null,
                  onSelected: (_) => setState(() => _countryId = null),
                ),
                ...catalog.countries.map(
                  (country) => FilterChip(
                    label: Text('${country.flagEmoji} ${country.name}'),
                    selected: _countryId == country.id,
                    onSelected: (_) => setState(() => _countryId = country.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(l10n.allServices),
                  selected: _categoryId == null,
                  onSelected: (_) => setState(() => _categoryId = null),
                ),
                ...catalog.categories.map(
                  (category) => FilterChip(
                    label: Text(category.name),
                    selected: _categoryId == category.id,
                    onSelected: (_) =>
                        setState(() => _categoryId = category.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (programs.isEmpty)
              EmptyState(
                title: l10n.noProgrammeFound,
                subtitle: l10n.tryChangingFilters,
                icon: Icons.public_off_outlined,
              ),
            ...programs.map((program) {
              final country = catalog.countries.firstWhere(
                (item) => item.id == program.countryId,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SectionCard(
                  title: program.title,
                  subtitle:
                      '${country.flagEmoji} ${country.name} · ${program.source.publisher}',
                  icon: Icons.flight_takeoff,
                  onTap: () => setState(() => _selected = program),
                  trailing: Icon(directionalChevron(context)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ProgramDetail extends StatelessWidget {
  const _ProgramDetail({
    required this.program,
    required this.country,
    required this.onBack,
  });

  final VisaProgram program;
  final Country country;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(program.title),
        leading: IconButton(
          icon: Icon(directionalBack(context)),
          onPressed: onBack,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                '${country.flagEmoji} ${country.name}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(program.summary),
              if (program.description != null) ...[
                const SizedBox(height: 12),
                Text(program.description!),
              ],
              if (program.processingTime != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${l10n.publishedTimeline}: ${program.processingTime}',
                ),
              ],
              if (program.fees != null) ...[
                const SizedBox(height: 8),
                Text('${l10n.publishedFee}: ${program.fees}'),
              ],
              if (program.requirements.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  l10n.publishedRequirements,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ...program.requirements.map(
                  (item) => ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.primaryRed,
                    ),
                    title: Text(item.text),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                l10n.source,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(program.source.title),
              SelectionArea(
                child: Text(
                  program.source.url,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.visaDisclaimer,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
