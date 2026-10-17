import 'package:flutter/material.dart';

import '../../domain/city.dart';
import 'city_clock_card.dart';

/// Changes arrangement only; all instants and city state come from the caller.
class CityClockGrid extends StatelessWidget {
  const CityClockGrid({
    super.key,
    required this.cities,
    required this.languageCode,
    required this.atUtc,
    required this.onSelect,
    required this.onRemove,
  });

  final List<City> cities;
  final String languageCode;
  final DateTime atUtc;
  final ValueChanged<City> onSelect;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final largeText = scale > 1.43;
      final columns = largeText
          ? (box.maxWidth >= 800 ? 2 : 1)
          : box.maxWidth >= 960
          ? 6
          : box.maxWidth >= 800
          ? 3
          : box.maxWidth >= 304
          ? 2
          : 1;
      final compact = columns >= 4 || box.maxWidth < 800;
      return GridView.builder(
        key: const ValueKey('city-clock-grid'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cities.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: largeText ? 180 * scale + 90 : 220,
        ),
        itemBuilder: (context, i) => CityClockCard(
          key: ValueKey('city-clock-${cities[i].id}'),
          city: cities[i],
          languageCode: languageCode,
          atUtc: atUtc,
          compact: compact,
          onRemove: compact ? null : () => onRemove(cities[i].id),
          onTap: () => onSelect(cities[i]),
        ),
      );
    },
  );
}
