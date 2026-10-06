import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
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
      body: feed.when(
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
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final theme = Theme.of(context);
                    final published = item.publishedAt;
                    final dateLabel = published
                        ?.toLocal()
                        .toIso8601String()
                        .split('T')
                        .first;
                    final categoryStyle = theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    );
                    return AnimatedOpacity(
                      opacity: 1,
                      duration: AppMotion.duration(context, AppMotion.fast),
                      curve: AppMotion.curve(context),
                      child: Semantics(
                        button: true,
                        label: item.title,
                        child: Card(
                          child: ListTile(
                            isThreeLine: true,
                            contentPadding:
                                const EdgeInsetsDirectional.fromSTEB(
                                  16,
                                  12,
                                  8,
                                  12,
                                ),
                            title: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 6),
                                Text(
                                  item.summary,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (dateLabel != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    dateLabel,
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                                if (item.category.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(item.category, style: categoryStyle),
                                ],
                              ],
                            ),
                            leading: Icon(
                              Icons.article_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            trailing: IconButton(
                              tooltip: item.saved
                                  ? l10n.removeBookmark
                                  : l10n.bookmark,
                              icon: Icon(
                                item.saved
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                              ),
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(feedRepositoryProvider)
                                      .setSaved(item.id, !item.saved);
                                  ref.invalidate(feedProvider(locale));
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.errorGeneric),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            onTap: () async {
                              try {
                                await ref
                                    .read(feedRepositoryProvider)
                                    .markRead(item.id);
                              } catch (_) {
                                // Read tracking is supplementary.
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
