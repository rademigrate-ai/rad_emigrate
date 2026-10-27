import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../../visa/data/editorial_repository.dart';
import '../widgets/editorial_source_review.dart';
import '../widgets/editorial_link_review.dart';

typedef ReconciliationKey = ({String locale, int offset});
final contentReconciliationProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ReconciliationKey>((ref, key) async {
      ref.watch(supabaseAuthUserIdProvider);
      final service = ref.watch(supabaseClientServiceProvider);
      if (!service.isInitialized) throw StateError('backend_unavailable');
      return editorialData(
        await service.client.rpc(
          'list_editorial_review_queue',
          params: {
            'p_locale': key.locale,
            'p_offset': key.offset,
            'p_limit': 10,
          },
        ),
      );
    });

/// Read/reconcile first: this page never offers bulk approval or publication.
/// Existing explicit CMS mutations remain separate and server-authorized.
class AdminContentReconciliationPage extends ConsumerStatefulWidget {
  const AdminContentReconciliationPage({super.key});
  @override
  ConsumerState<AdminContentReconciliationPage> createState() => _State();
}

class _State extends ConsumerState<AdminContentReconciliationPage> {
  int offset = 0;
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode == 'fa'
        ? 'fa'
        : 'en';
    final key = (locale: locale, offset: offset);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/admin/cms'),
        title: Text(
          locale == 'fa'
              ? 'بازبینی یکپارچه‌سازی محتوا'
              : 'Content reconciliation',
        ),
      ),
      body: ref
          .watch(contentReconciliationProvider(key))
          .when(
            loading: () => Center(
              child: RadLoadingIndicator(
                label: locale == 'fa'
                    ? 'در حال دریافت محتوا'
                    : 'Loading content',
              ),
            ),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () =>
                    ref.invalidate(contentReconciliationProvider(key)),
                child: Text(
                  locale == 'fa'
                      ? 'دسترسی یا دریافت محتوا ناموفق؛ تلاش دوباره'
                      : 'Access or loading failed; retry',
                ),
              ),
            ),
            data: (data) {
              final items = editorialRows(data['items']);
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        context.push('/visa/content-countries?preview=true'),
                    icon: const Icon(Icons.preview_outlined),
                    label: Text(
                      locale == 'fa'
                          ? 'پیش‌نمایش کشورها و دسته‌بندی‌های ویزا'
                          : 'Preview Visa countries and categories',
                    ),
                  ),
                  Text(
                    locale == 'fa'
                        ? 'ورود داده، تأیید حقوقی یا اجازه انتشار نیست.'
                        : 'Import is not legal verification or publication approval.',
                  ),
                  for (final item in items)
                    Card(
                      child: ExpansionTile(
                        title: Text('${item['title']}'),
                        subtitle: Text(
                          '${item['editorial_state']} · ${item['verification_state']}',
                        ),
                        children: [
                          SourceReviewButton(article: item),
                          EditorialLinkReview(
                            articleId: item['id'] as String,
                            locale: locale,
                          ),
                          TextButton(
                            onPressed: () => context.push(
                              '/visa/content/${item['id']}?locale=$locale&preview=true',
                            ),
                            child: Text(
                              locale == 'fa'
                                  ? 'خواندن متن کامل'
                                  : 'Read complete body',
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push(
                              '/admin/cms/canonical/${item['id']}',
                            ),
                            child: Text(
                              locale == 'fa'
                                  ? 'ویرایش و گردش کار سردبیری'
                                  : 'Editorial workflow',
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: SelectableText(
                              const JsonEncoder.withIndent('  ')
                                  .convert(item['composition']),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: offset == 0
                            ? null
                            : () => setState(() => offset -= 10),
                        child: Text(locale == 'fa' ? 'قبلی' : 'Previous'),
                      ),
                      TextButton(
                        onPressed: items.length < 10
                            ? null
                            : () => setState(() => offset += 10),
                        child: Text(locale == 'fa' ? 'بعدی' : 'Next'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
    );
  }
}
