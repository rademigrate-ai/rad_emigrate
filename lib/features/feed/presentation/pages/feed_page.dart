import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../data/feed_repository.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  String _locale = 'fa';

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider(_locale));
    final rtl = _locale == 'fa';
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(rtl ? 'تازه‌های راد' : 'RAD updates'),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _locale = rtl ? 'en' : 'fa');
              },
              child: Text(rtl ? 'English' : 'فارسی'),
            ),
          ],
        ),
        body: feed.when(
          loading: () => const LoadingView(message: 'Loading RAD updates…'),
          error: (error, _) => ErrorView(
            message: rtl
                ? 'دریافت تازه‌ها ممکن نشد.'
                : 'Updates could not be loaded.',
            onRetry: () => ref.invalidate(feedProvider(_locale)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Text(
                  rtl
                      ? 'هنوز محتوای تأییدشده‌ای منتشر نشده است.'
                      : 'No reviewed updates have been published yet.',
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.refresh(feedProvider(_locale).future),
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
                        tooltip: item.saved ? 'Remove bookmark' : 'Bookmark',
                        icon: Icon(
                          item.saved ? Icons.bookmark : Icons.bookmark_border,
                        ),
                        onPressed: () async {
                          await ref
                              .read(feedRepositoryProvider)
                              .setSaved(item.id, !item.saved);
                          ref.invalidate(feedProvider(_locale));
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
      ),
    );
  }
}
