import '../../../../core/theme/premium_tokens.dart';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_motion.dart';
import '../../domain/entities/visa_entities.dart';
import 'country_photography.dart';

/// Mobile-first country carousel: exactly two complete cards visible,
/// 16:9 aspect, 20px radius, 10px spacing, one-card snap, no autoplay.
class CountryCarousel extends StatefulWidget {
  const CountryCarousel({
    super.key,
    required this.countries,
    required this.categoryLabels,
    required this.onSelect,
  });

  final List<Country> countries;
  final Map<String, List<String>> categoryLabels;
  final ValueChanged<Country> onSelect;

  @override
  State<CountryCarousel> createState() => _CountryCarouselState();
}

class _CountryCarouselState extends State<CountryCarousel> {
  late final PageController _controller;
  var _index = 0;
  var _showHint = true;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.52);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(AppMotion.carouselPause, () {
        if (mounted) setState(() => _showHint = false);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = width >= AppBreakpoints.desktop ? 28.0 : 16.0;
    final reduceMotion = AppMotion.reduceMotion(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: ((width - pad * 2) * 0.48) * 9 / 16 + 8,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.countries.length,
            padEnds: false,
            onPageChanged: (i) => setState(() {
              _index = i;
              _showHint = false;
            }),
            itemBuilder: (context, i) {
              final country = widget.countries[i];
              final labels = widget.categoryLabels[country.id] ?? const [];
              return Padding(
                padding: EdgeInsetsDirectional.only(
                  start: i == 0 ? pad : 5,
                  end: i == widget.countries.length - 1 ? pad : 5,
                ),
                child: _CountryCard(
                  country: country,
                  categoryLabels: labels,
                  onTap: () => widget.onSelect(country),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.countries.length; i++)
              AnimatedContainer(
                duration: reduceMotion ? Duration.zero : AppMotion.hover,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _index ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
          ],
        ),
        if (_showHint && widget.countries.length > 1) ...[
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: Text(
              Directionality.of(context) == TextDirection.rtl
                  ? 'برای دیدن کشورهای بیشتر بکشید'
                  : 'Swipe for more destinations',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CountryCard extends StatelessWidget {
  const _CountryCard({
    required this.country,
    required this.categoryLabels,
    required this.onTap,
  });

  final Country country;
  final List<String> categoryLabels;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      button: true,
      label: '${country.name}. ${categoryLabels.join(', ')}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.lg),
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
                        colors: [
                          Color(0x00000000),
                          Color(0x66000000),
                          Color(0xB3000000),
                        ],
                        stops: [0.35, 0.7, 1],
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 10,
                    end: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        country.flagEmoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 12,
                    end: 12,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          country.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (categoryLabels.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            categoryLabels.take(3).join(isRtl ? ' · ' : ' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFE8F0F2),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Alphabetical searchable country list for the search panel.
class CountrySearchPanel extends StatelessWidget {
  const CountrySearchPanel({
    super.key,
    required this.countries,
    required this.query,
    required this.onQueryChanged,
    required this.onSelect,
  });

  final List<Country> countries;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Country> onSelect;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered =
        countries
            .where(
              (c) =>
                  q.isEmpty ||
                  c.name.toLowerCase().contains(q) ||
                  c.code.toLowerCase().contains(q),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchBar(
          hintText: Directionality.of(context) == TextDirection.rtl
              ? 'جستجوی کشور…'
              : 'Search countries…',
          leading: const Icon(Icons.search),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.surface,
          ),
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 8),
        ...filtered.map(
          (c) => ListTile(
            dense: true,
            leading: Text(c.flagEmoji, style: const TextStyle(fontSize: 22)),
            title: Text(c.name),
            trailing: Text(
              c.code,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            onTap: () => onSelect(c),
          ),
        ),
      ],
    );
  }
}
