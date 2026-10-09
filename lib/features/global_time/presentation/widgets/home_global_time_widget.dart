import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/global_time_controller.dart';
import 'city_clock_card.dart';

/// Compact Global Time strip for the Home dashboard.
class HomeGlobalTimeWidget extends ConsumerWidget {
  const HomeGlobalTimeWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(globalTimeControllerProvider);
    final lang = Localizations.localeOf(context).languageCode;
    final cities = state.favorites.take(3).toList();

    if (cities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              AppLocalizations.of(context).worldTimeTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/world-clock'),
              child: Text(AppLocalizations.of(context).worldTimeViewAll),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cities.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              return SizedBox(
                width: 160,
                child: CityClockCard(
                  city: cities[i],
                  languageCode: lang,
                  compact: true,
                  onTap: () => context.go('/world-clock'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
