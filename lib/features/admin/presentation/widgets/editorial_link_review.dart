import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/supabase/rad_contract.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../../visa/data/editorial_repository.dart';

typedef LinkReviewKey = ({String articleId, String locale});
final editorialLinkReviewProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, LinkReviewKey>((ref, key) async {
      ref.watch(supabaseAuthUserIdProvider);
      final service = ref.watch(supabaseClientServiceProvider);
      if (!service.isInitialized) throw StateError('backend_unavailable');
      return editorialData(
        await service.client
            .rpc(
              'get_editorial_link_review',
              params: {'p_article_id': key.articleId, 'p_locale': key.locale},
            )
            .timeout(const Duration(seconds: 20)),
      );
    });

class EditorialLinkReview extends ConsumerStatefulWidget {
  const EditorialLinkReview({
    super.key,
    required this.articleId,
    required this.locale,
  });
  final String articleId;
  final String locale;
  @override
  ConsumerState<EditorialLinkReview> createState() => _State();
}

class _State extends ConsumerState<EditorialLinkReview> {
  bool expanded = false, busy = false;
  String? error;
  final requestKeys = <String, String>{};
  Future<void> decide(Map<String, dynamic> link, String decision) async {
    final fa = widget.locale == 'fa';
    final owner = ref.read(supabaseAuthUserIdProvider).valueOrNull;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(
          fa
              ? 'این تصمیم فقط ارتباط مقاله را بررسی می‌کند و محتوا را تأیید یا منتشر نمی‌کند.'
              : 'This reviews the article link. It does not approve or publish content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(fa ? 'انصراف' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(fa ? 'ثبت تصمیم' : 'Confirm decision'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        owner == null ||
        ref.read(supabaseAuthUserIdProvider).valueOrNull != owner) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final country = link['review_kind'] == 'country';
    final identity =
        '${link['review_kind']}:${link['country_code'] ?? link['related_id']}:${link['revision']}:$decision';
    final key = requestKeys.putIfAbsent(identity, newRadRequestKey);
    try {
      final service = ref.read(supabaseClientServiceProvider);
      await service.client
          .rpc(
            country
                ? 'review_country_other_title'
                : 'review_editorial_relation',
            params: {
              if (country) 'p_country_code': link['country_code'],
              if (country) 'p_article_id': widget.articleId,
              if (!country) 'p_parent_id': widget.articleId,
              if (!country) 'p_related_id': link['related_id'],
              'p_expected_revision': link['revision'],
              'p_decision': decision,
              'p_rank': link['rank'],
              'p_request_key': key,
            },
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      ref.invalidate(
        editorialLinkReviewProvider((
          articleId: widget.articleId,
          locale: widget.locale,
        )),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => error = fa
              ? 'ثبت تصمیم ناموفق بود؛ نسخه جدید را بررسی و دوباره تلاش کنید.'
              : 'Decision failed. Refresh the current revision and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fa = widget.locale == 'fa';
    final key = (articleId: widget.articleId, locale: widget.locale);
    return ExpansionTile(
      title: Text(
        fa ? 'بازبینی ارتباط‌های دیگر عناوین' : 'Review Other Titles links',
      ),
      onExpansionChanged: (value) => setState(() => expanded = value),
      children: [
        if (expanded)
          ref
              .watch(editorialLinkReviewProvider(key))
              .when(
                loading: () => RadLoadingIndicator(
                  label: fa ? 'در حال دریافت ارتباط‌ها' : 'Loading links',
                ),
                error: (_, _) => TextButton(
                  onPressed: () =>
                      ref.invalidate(editorialLinkReviewProvider(key)),
                  child: Text(fa ? 'دریافت دوباره' : 'Retry'),
                ),
                data: (data) => Column(
                  children: [
                    if (error != null) Text(error!),
                    for (final link in [
                      ...editorialRows(data['category_links']),
                      ...editorialRows(data['country_links']),
                    ])
                      ListTile(
                        title: Text('${link['title'] ?? link['country_code']}'),
                        subtitle: Text('${link['state']}'),
                        trailing: Wrap(
                          children: [
                            TextButton(
                              onPressed: busy || link['state'] == 'approved'
                                  ? null
                                  : () => decide(link, 'approved'),
                              child: Text(fa ? 'تأیید ارتباط' : 'Approve link'),
                            ),
                            TextButton(
                              onPressed: busy || link['state'] == 'rejected'
                                  ? null
                                  : () => decide(link, 'rejected'),
                              child: Text(fa ? 'رد ارتباط' : 'Reject link'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ],
    );
  }
}
