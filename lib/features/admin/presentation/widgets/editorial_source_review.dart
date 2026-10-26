import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../../visa/data/editorial_repository.dart';

typedef SourceSnapshotKey = ({
  String articleId,
  String revisionId,
  String snapshotId,
});
final editorialSourceSnapshotProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, SourceSnapshotKey>((ref, key) async {
      ref.watch(supabaseAuthUserIdProvider);
      final service = ref.watch(supabaseClientServiceProvider);
      if (!service.isInitialized) throw StateError('backend_unavailable');
      return editorialData(
        await service.client
            .rpc(
              'get_editorial_source_snapshot',
              params: {
                'p_article_id': key.articleId,
                'p_revision_id': key.revisionId,
                'p_snapshot_id': key.snapshotId,
              },
            )
            .timeout(const Duration(seconds: 20)),
      );
    });

class SourceReviewButton extends ConsumerWidget {
  const SourceReviewButton({super.key, required this.article});
  final Map<String, dynamic> article;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final composition = article['composition'];
    final snapshots = <String, String>{};
    if (composition is Map) {
      for (final section in editorialRows(composition['sections'])) {
        for (final block in editorialRows(section['blocks'])) {
          for (final source in editorialRows(block['provenance'])) {
            if (source['snapshot_id'] is String) {
              snapshots[source['snapshot_id'] as String] =
                  source['url'] as String? ?? '';
            }
          }
        }
      }
    }
    if (snapshots.isEmpty) return const SizedBox.shrink();
    return TextButton.icon(
      icon: const Icon(Icons.source_outlined),
      label: Text(
        fa
            ? 'اصل منابع (${snapshots.length})'
            : 'Original sources (${snapshots.length})',
      ),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => _SessionBoundDialog(
          owner: owner,
          child: AlertDialog(
            title: Text(
              fa ? 'منابع اصلی ثبت‌شده' : 'Captured original sources',
            ),
            content: SizedBox(
              width: 850,
              height: 500,
              child: ListView(
                children: [
                  for (final source in snapshots.entries)
                    ListTile(
                      title: Text(
                        source.value,
                        textDirection: TextDirection.ltr,
                      ),
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        final key = (
                          articleId: article['id'] as String,
                          revisionId: article['revision_id'] as String,
                          snapshotId: source.key,
                        );
                        showDialog<void>(
                          context: context,
                          builder: (_) => _SessionBoundDialog(
                            owner: owner,
                            child: _SnapshotDialog(snapshotKey: key),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(fa ? 'بستن' : 'Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnapshotDialog extends ConsumerWidget {
  const _SnapshotDialog({required this.snapshotKey});
  final SourceSnapshotKey snapshotKey;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    return AlertDialog(
      title: Text(fa ? 'نسخه تغییرناپذیر منبع' : 'Immutable source snapshot'),
      content: SizedBox(
        width: 900,
        height: 600,
        child: ref
            .watch(editorialSourceSnapshotProvider(snapshotKey))
            .when(
              loading: () => RadLoadingIndicator(
                label: fa ? 'در حال دریافت منبع' : 'Loading source',
              ),
              error: (_, _) => TextButton(
                onPressed: () => ref.invalidate(
                  editorialSourceSnapshotProvider(snapshotKey),
                ),
                child: Text(
                  fa
                      ? 'دسترسی یا دریافت ناموفق؛ تلاش دوباره'
                      : 'Access or loading failed; retry',
                ),
              ),
              data: (source) => Directionality(
                textDirection: source['locale'] == 'fa'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectableText('${source['title'] ?? ''}'),
                      SelectableText(
                        '${source['url'] ?? ''}',
                        textDirection: TextDirection.ltr,
                      ),
                      Text(
                        fa
                            ? 'دریافت منبع به معنی تأیید حقوقی نیست.'
                            : 'Source retrieval is not legal verification.',
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        source['body_text'] as String? ?? '',
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(height: 1.8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(fa ? 'بستن' : 'Close'),
        ),
      ],
    );
  }
}

// An open modal must not retain one account's private evidence after logout
// or a direct switch to another account. Backend authorization stays decisive.
class _SessionBoundDialog extends ConsumerWidget {
  const _SessionBoundDialog({required this.owner, required this.child});
  final String? owner;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
    if (owner != null && current == owner) return child;
    return AlertDialog(
      content: const Text(
        'Session changed. Reopen the review after signing in.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
