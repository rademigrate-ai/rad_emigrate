import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/feed_repository.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final feed = ref.watch(feedProvider(locale));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.feedTitle)),
      body: PremiumCanvas(
        accent: AppColors.teal,
        child: feed.when(
          loading: () => LoadingState(message: l10n.loadingUpdates),
          error: (error, _) => ErrorState(
            message: l10n.updatesLoadFailed,
            onRetry: () => ref.invalidate(feedProvider(locale)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return EmptyState(
                title: l10n.noReviewedUpdates,
                subtitle: l10n.catalogueDisclaimer,
                icon: Icons.newspaper_outlined,
                actionLabel: l10n.visaPrograms,
                onAction: () => context.go('/visa'),
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.refresh(feedProvider(locale).future),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return PremiumHeroPanel(
                          kicker: const EditorialKicker(
                            index: '05',
                            label: 'RAD BRIEFING',
                            dark: true,
                          ),
                          title: l10n.radUpdates,
                          body: l10n.feedPublishedOnly,
                          trailing: const RadOrbit(size: 165, showBrand: false),
                        );
                      }
                      final item = items[index - 1];
                      return MotionStagger(
                        key: ValueKey(item.id),
                        index: index - 1,
                        child: _EditorialFeedCard(
                          index: index,
                          item: item,
                          locale: locale,
                          onRead: () async {
                            try {
                              await ref
                                  .read(feedRepositoryProvider)
                                  .markRead(item.id);
                            } catch (_) {
                              // Read tracking is supplementary.
                            }
                          },
                          onSaved: () async {
                            try {
                              await ref
                                  .read(feedRepositoryProvider)
                                  .setSaved(item.id, !item.saved);
                              ref.invalidate(feedProvider(locale));
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.errorGeneric)),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EditorialFeedCard extends StatelessWidget {
  const _EditorialFeedCard({
    required this.index,
    required this.item,
    required this.locale,
    required this.onRead,
    required this.onSaved,
  });

  final int index;
  final FeedEntry item;
  final String locale;
  final Future<void> Function() onRead;
  final Future<void> Function() onSaved;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dateLabel = item.publishedAt
        ?.toLocal()
        .toIso8601String()
        .split('T')
        .first;
    return Semantics(
      button: true,
      label: item.title,
      child: AppCard(
        onTap: onRead,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'UPDATE ${index.toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: item.saved ? l10n.removeBookmark : l10n.bookmark,
                  icon: Icon(
                    item.saved ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  onPressed: onSaved,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(item.summary, maxLines: 3, overflow: TextOverflow.ellipsis),
            if (dateLabel != null) ...[
              const SizedBox(height: 8),
              Text(dateLabel, style: theme.textTheme.labelSmall),
            ],
            if (item.category.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.category,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primaryRed,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
