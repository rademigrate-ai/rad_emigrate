part of 'visa_page.dart';

class _CountriesStage extends StatefulWidget {
  const _CountriesStage({
    required this.catalog,
    required this.l10n,
    required this.query,
    required this.onQuery,
    required this.onSelect,
  });
  final VisaCatalog catalog;
  final AppLocalizations l10n;
  final String query;
  final ValueChanged<String> onQuery;
  final ValueChanged<Country> onSelect;
  @override
  State<_CountriesStage> createState() => _CountriesStageState();
}

class _CountriesStageState extends State<_CountriesStage> {
  String? _category;
  IconData _categoryIcon(VisaCategory category) {
    final key = '${category.slug} ${category.name}'.toLowerCase();
    if (RegExp('study|education|تحصیل').hasMatch(key)) {
      return Icons.school_outlined;
    }
    if (RegExp('work|کار').hasMatch(key)) {
      return Icons.work_outline;
    }
    if (RegExp('invest|سرمایه').hasMatch(key)) {
      return Icons.trending_up;
    }
    if (RegExp('visit|tour|گردش').hasMatch(key)) {
      return Icons.flight_outlined;
    }
    return Icons.public_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.catalog;
    final l10n = widget.l10n;
    final query = widget.query.trim().toLowerCase();
    final countries = catalog.countries.where((country) {
      final programs = catalog.programsForCountry(country.id);
      return (_category == null ||
              programs.any((p) => p.categoryId == _category)) &&
          (query.isEmpty ||
              country.name.toLowerCase().contains(query) ||
              country.code.toLowerCase().contains(query) ||
              programs.any((p) => p.title.toLowerCase().contains(query)));
    }).toList();
    final colors = [
      const Color(0xFFD91F2B),
      const Color(0xFF345CFF),
      const Color(0xFF00A986),
      const Color(0xFF3186DA),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextFormField(
              initialValue: widget.query,
              onChanged: widget.onQuery,
              decoration: InputDecoration(
                hintText: l10n.searchProgrammes,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
              ),
            ),
            if (catalog.categories.isNotEmpty) ...[
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < catalog.categories.length; i++)
                      SizedBox(
                        width: MediaQuery.textScalerOf(context).scale(14) > 20
                            ? (constraints.maxWidth - 8) / 2
                            : (constraints.maxWidth - 24) / 4,
                        child: Semantics(
                          selected: _category == catalog.categories[i].id,
                          child: ReferenceQuickAction(
                            icon: _categoryIcon(catalog.categories[i]),
                            color: _category == catalog.categories[i].id
                                ? context.premium.accent
                                : colors[i % colors.length],
                            label: catalog.categories[i].name,
                            onTap: () => setState(
                              () => _category =
                                  _category == catalog.categories[i].id
                                  ? null
                                  : catalog.categories[i].id,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            ReferenceSection(
              title: l10n.destinationsHeading,
              action: _category != null ? l10n.allItems : null,
              onAction: () => setState(() => _category = null),
            ),
            if (countries.isEmpty)
              EmptyState(
                title: l10n.catalogueUnavailable,
                subtitle: l10n.catalogueDisclaimer,
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    (constraints.maxWidth < 304 ||
                        (constraints.maxWidth < 600 &&
                            MediaQuery.textScalerOf(context).scale(14) > 20))
                    ? 1
                    : constraints.maxWidth >= 1100
                    ? 4
                    : constraints.maxWidth >= 840
                    ? 3
                    : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: countries.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final country = countries[index];
                    final labels = catalog
                        .categoriesForCountry(country.id)
                        .map((c) => c.name)
                        .toList();
                    return Semantics(
                      key: ValueKey('destination-card-${country.id}'),
                      label: country.name,
                      button: true,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Material(
                          color: context.premium.surface,
                          child: InkWell(
                            onTap: () => widget.onSelect(country),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CountryPhotography.image(
                                  code: country.code,
                                  destination: country.slug,
                                  fit: BoxFit.cover,
                                ),
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        stops: const [.38, .72, 1],
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: .35),
                                          Colors.black.withValues(alpha: .88),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                PositionedDirectional(
                                  start: 12,
                                  end: 12,
                                  bottom: 12,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        country.flagEmoji,
                                        style: const TextStyle(fontSize: 25),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        country.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                      ),
                                      if (labels.isNotEmpty)
                                        Text(
                                          labels.take(3).join(' / '),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: Colors.white),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              l10n.catalogueDisclaimer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
