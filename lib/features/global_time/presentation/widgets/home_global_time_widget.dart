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
    final theme = Theme.of(context);
    final cities = state.favorites.take(3).toList();
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(l10n.worldTimeTitle, style: theme.textTheme.titleMedium),
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/world-clock'),
              child: Text(l10n.worldTimeViewAll),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: state.isLoading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, _) => Container(
                    width: 160,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor),
                    ),
                  ),
                )
              : cities.isEmpty
                  ? Center(
                      child: Text(
                        lang == 'fa'
                            ? 'شهری برای نمایش نیست — از ساعت جهانی اضافه کنید'
                            : 'No cities yet — add some in World Time',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : ListView.separated(
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
