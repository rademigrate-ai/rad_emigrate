import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../core/widgets/premium_visuals.dart';
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
      appBar: AppBar(title: Text(l10n.visaPathways)),
      body: PremiumCanvas(
        accent: AppColors.teal,
        child: catalog.when(
          loading: () => LoadingState.section(message: l10n.loadingCatalogue),
          error: (_, _) => ErrorState(
            message: l10n.catalogueUnavailable,
            onRetry: () => ref.invalidate(visaCatalogProvider(locale)),
          ),
          data: (value) => _catalog(context, value, l10n),
        ),
      ),
    );
  }

  Widget _catalog(
    BuildContext context,
    VisaCatalog catalog,
    AppLocalizations l10n,
  ) {
    final query = _query.trim().toLowerCase();
    final programs = catalog.programs
        .where(
          (program) =>
              (_countryId == null || program.countryId == _countryId) &&
              (_categoryId == null || program.categoryId == _categoryId) &&
              (query.isEmpty ||
                  program.title.toLowerCase().contains(query) ||
                  program.summary.toLowerCase().contains(query)),
        )
        .toList();
    final pendingColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            PremiumHeroPanel(
              kicker: const EditorialKicker(
                index: '02',
                label: 'PATHWAY EXPLORER',
                dark: true,
              ),
              title: l10n.findPathway,
              body: l10n.catalogueDisclaimer,
              trailing: const RadOrbit(size: 190, showBrand: false),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFCBE0E1)),
              ),
              child: SearchBar(
                hintText: l10n.searchProgrammes,
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: const WidgetStatePropertyAll(
                  Color(0xFFF5FAFA),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 18),
            const EditorialKicker(index: '03', label: 'FILTER THE CATALOGUE'),
            const SizedBox(height: 12),
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
            ...programs.asMap().entries.map((entry) {
              final program = entry.value;
              final country = catalog.countries.firstWhere(
                (item) => item.id == program.countryId,
              );
              final hasStructure =
                  program.requirements.isNotEmpty || program.steps.isNotEmpty;
              return MotionStagger(
                index: entry.key,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ExplorerProgramCard(
                    program: program,
                    country: country,
                    pending: !hasStructure,
                    pendingColor: pendingColor,
                    pendingMessage: l10n.structuredDetailsPending,
                    onTap: () => setState(() => _selected = program),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ExplorerProgramCard extends StatelessWidget {
  const _ExplorerProgramCard({
    required this.program,
    required this.country,
    required this.pending,
    required this.pendingColor,
    required this.pendingMessage,
    required this.onTap,
  });

  final VisaProgram program;
  final Country country;
  final bool pending;
  final Color pendingColor;
  final String pendingMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0B2430),
              border: Border.all(color: const Color(0xFF2E6872)),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.teal.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    country.flagEmoji,
                    style: const TextStyle(fontSize: 25),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        country.name.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF80E7E0),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        program.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        program.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFBDD2D8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    if (pending)
                      Tooltip(
                        message: pendingMessage,
                        child: Icon(
                          Icons.hourglass_empty_outlined,
                          color: pendingColor,
                        ),
                      ),
                    const SizedBox(height: 14),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF80E7E0),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
          tooltip: l10n.back,
          icon: Icon(directionalBack(context)),
          onPressed: onBack,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            children: [
              Text(
                '${country.flagEmoji} ${country.name}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                program.summary,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if ((program.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(program.description!),
              ],
              if (program.processingTime != null || program.fees != null) ...[
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        if (program.processingTime != null)
                          _Fact(
                            icon: Icons.schedule_outlined,
                            label: l10n.publishedTimeline,
                            value: program.processingTime!,
                          ),
                        if (program.fees != null)
                          _Fact(
                            icon: Icons.payments_outlined,
                            label: l10n.publishedFee,
                            value: program.fees!,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (program.requirements.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text(
                  l10n.publishedRequirements,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                ...program.requirements.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.primaryRed,
                    ),
                    title: Text(item.text),
                  ),
                ),
              ],
              if (program.steps.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text(
                  l10n.applicationSteps,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ...program.steps.asMap().entries.map(
                  (entry) => Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${entry.key + 1}')),
                      title: Text(entry.value.title),
                      subtitle: entry.value.description.isEmpty
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(entry.value.description),
                            ),
                    ),
                  ),
                ),
              ],
              if (program.requirements.isEmpty && program.steps.isEmpty) ...[
                const SizedBox(height: 22),
                EmptyState(
                  title: l10n.structuredDetailsPending,
                  subtitle: l10n.structuredDetailsPendingBody,
                  icon: Icons.fact_check_outlined,
                ),
              ],
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.source,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${program.source.publisher} · ${program.source.title}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.structuredSourceNote,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
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

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(value),
            ],
          ),
        ),
      ],
    ),
  );
}
