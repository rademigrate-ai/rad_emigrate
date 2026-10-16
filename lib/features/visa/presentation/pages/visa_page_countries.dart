part of 'visa_page.dart';

class _CountriesStage extends StatelessWidget {
  const _CountriesStage({
    required this.catalog,
    required this.l10n,
    required this.showSearch,
    required this.query,
    required this.onQuery,
    required this.onSelect,
  });

  final VisaCatalog catalog;
  final AppLocalizations l10n;
  final bool showSearch;
  final String query;
  final ValueChanged<String> onQuery;
  final ValueChanged<Country> onSelect;

  @override
  Widget build(BuildContext context) {
    if (catalog.countries.isEmpty) {
      return EmptyState(
        title: l10n.catalogueUnavailable,
        subtitle: l10n.catalogueDisclaimer,
      );
    }

    final categoryLabels = <String, List<String>>{
      for (final c in catalog.countries)
        c.id: catalog.categoriesForCountry(c.id).map((x) => x.name).toList(),
    };

    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 600;
    final isDesktop = width >= 1100;
    final grouped = <_VisaContinent, List<Country>>{};
    for (final country in catalog.countries) {
      grouped.putIfAbsent(_continentFor(country.code), () => []).add(country);
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 1100 : 920),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 28 : 16,
            12,
            isDesktop ? 28 : 16,
            32,
          ),
          children: [
            PremiumHeroPanel(
              kicker: const EditorialKicker(
                index: '02',
                label: 'DESTINATIONS',
                dark: true,
              ),
              title: l10n.findPathway,
              body: l10n.catalogueDisclaimer,
            ),
            const SizedBox(height: 20),
            if (showSearch)
              CountrySearchPanel(
                countries: catalog.countries,
                query: query,
                onQueryChanged: onQuery,
                onSelect: onSelect,
              )
            else
              for (final group in grouped.entries) ...[
                _ContinentHeading(
                  continent: group.key,
                  count: group.value.length,
                ),
                const SizedBox(height: 10),
                if (isDesktop)
                  _CountryGrid(
                    countries: group.value,
                    categoryLabels: categoryLabels,
                    columns: 3,
                    onSelect: onSelect,
                  )
                else if (isTablet)
                  _CountryGrid(
                    countries: group.value,
                    categoryLabels: categoryLabels,
                    columns: 2,
                    onSelect: onSelect,
                  )
                else
                  CountryCarousel(
                    countries: group.value,
                    categoryLabels: categoryLabels,
                    onSelect: onSelect,
                  ),
                const SizedBox(height: 24),
              ],
          ],
        ),
      ),
    );
  }
}

enum _VisaContinent { northAmerica, europe, asia, oceania, middleEast, other }

_VisaContinent _continentFor(String rawCode) {
  final code = rawCode.toUpperCase();
  if (const {'CA', 'US', 'MX'}.contains(code)) {
    return _VisaContinent.northAmerica;
  }
  if (const {
    'AT',
    'BE',
    'CH',
    'DE',
    'DK',
    'ES',
    'FI',
    'FR',
    'GB',
    'IE',
    'IT',
    'NL',
    'NO',
    'PT',
    'SE',
  }.contains(code)) {
    return _VisaContinent.europe;
  }
  if (const {
    'AE',
    'BH',
    'IL',
    'JO',
    'KW',
    'OM',
    'QA',
    'SA',
    'TR',
  }.contains(code)) {
    return _VisaContinent.middleEast;
  }
  if (const {'AU', 'NZ'}.contains(code)) return _VisaContinent.oceania;
  if (const {'CN', 'IN', 'JP', 'KR', 'MY', 'SG', 'TH'}.contains(code)) {
    return _VisaContinent.asia;
  }
  return _VisaContinent.other;
}

class _ContinentHeading extends StatelessWidget {
  const _ContinentHeading({required this.continent, required this.count});

  final _VisaContinent continent;
  final int count;

  @override
  Widget build(BuildContext context) {
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final label = switch (continent) {
      _VisaContinent.northAmerica => fa ? 'آمریکای شمالی' : 'North America',
      _VisaContinent.europe => fa ? 'اروپا' : 'Europe',
      _VisaContinent.asia => fa ? 'آسیا' : 'Asia',
      _VisaContinent.oceania => fa ? 'اقیانوسیه' : 'Oceania',
      _VisaContinent.middleEast => fa ? 'خاورمیانه' : 'Middle East',
      _VisaContinent.other => fa ? 'سایر مقصدها' : 'Other destinations',
    };
    return Semantics(
      header: true,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primaryRed,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryGrid extends StatelessWidget {
  const _CountryGrid({
    required this.countries,
    required this.categoryLabels,
    required this.columns,
    required this.onSelect,
  });

  final List<Country> countries;
  final Map<String, List<String>> categoryLabels;
  final int columns;
  final ValueChanged<Country> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: countries.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 16 / 9,
      ),
      itemBuilder: (context, i) {
        final country = countries[i];
        final labels = categoryLabels[country.id] ?? const [];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelect(country),
            borderRadius: BorderRadius.circular(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CountryPhotography.image(
                    code: country.code,
                    fit: BoxFit.cover,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x99000000)],
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 10,
                    end: 10,
                    child: Text(
                      country.flagEmoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  PositionedDirectional(
                    start: 14,
                    end: 14,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          country.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        if (labels.isNotEmpty)
                          Text(
                            labels.take(3).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFE8F0F2),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
