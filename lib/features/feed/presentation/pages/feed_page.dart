import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
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
      appBar: AppBar(
        title: Text(l10n.feedTitle),
      ),
      body: feed.when(
        loading: () => LoadingView(message: l10n.loadingUpdates),
        error: (error, _) => ErrorView(
          message: l10n.updatesLoadFailed,
          onRetry: () => ref.invalidate(feedProvider(locale)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.noReviewedUpdates,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(feedProvider(locale).future),
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    isThreeLine: true,
                    title: Text(item.title),
                    subtitle: Text(item.summary),
                    leading: const Icon(Icons.article_outlined),
                    trailing: IconButton(
                      tooltip:
                          item.saved ? l10n.removeBookmark : l10n.bookmark,
                      icon: Icon(
                        item.saved ? Icons.bookmark : Icons.bookmark_border,
                      ),
                      onPressed: () async {
                        await ref
                            .read(feedRepositoryProvider)
                            .setSaved(item.id, !item.saved);
                        ref.invalidate(feedProvider(locale));
                      },
                    ),
                    onTap: () {
                      ref.read(feedRepositoryProvider).markRead(item.id);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
