import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../data/editorial_repository.dart';
import '../../domain/editorial_country_names.dart';

/// Includes country, multi-country and general articles without assigning a
/// fabricated country. One stable reader route serves each article identity.
class OtherTitlesLibraryPage extends ConsumerStatefulWidget {
  const OtherTitlesLibraryPage({super.key, this.preview = false});
  final bool preview;

  @override
  ConsumerState<OtherTitlesLibraryPage> createState() => _LibraryState();
}

class _LibraryState extends ConsumerState<OtherTitlesLibraryPage> {
  final positions = <String?>[null];
  String? previousLocale;

  @override
  void didUpdateWidget(covariant OtherTitlesLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preview != widget.preview) {
      positions
        ..clear()
        ..add(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode == 'fa'
        ? 'fa'
        : 'en';
    final fa = locale == 'fa';
    if (previousLocale != locale) {
      positions
        ..clear()
        ..add(null);
      previousLocale = locale;
    }
    final key = (
      locale: locale,
      preview: widget.preview,
      cursor: positions.last,
    );
    return Directionality(
      textDirection: fa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallback: '/visa'),
          title: Text(fa ? 'دیگر عناوین' : 'Other Titles'),
        ),
        body: ref
            .watch(otherTitlesLibraryProvider(key))
            .when(
              loading: () => RadLoadingIndicator(
                label: fa ? 'در حال دریافت مقالات' : 'Loading articles',
              ),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () =>
                      ref.invalidate(otherTitlesLibraryProvider(key)),
                  child: Text(
                    fa
                        ? 'دریافت مقالات ناموفق؛ تلاش دوباره'
                        : 'Articles unavailable; retry',
                  ),
                ),
              ),
              data: (data) {
                final items = editorialRows(data['items']);
                final seen = <String>{};
                final unique = items.where(
                  (item) =>
                      item['id'] is String && seen.add(item['id'] as String),
                );
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          fa
                              ? 'مقالات کشورها، چندکشوری و عمومی'
                              : 'Country, multi-country and general articles',
                        ),
                        if (widget.preview)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              fa
                                  ? 'پیش‌نویس‌های منتشرنشده — دسترسی مدیر'
                                  : 'Unpublished drafts — administrator access',
                            ),
                          ),
                        if (items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              widget.preview
                                  ? (fa
                                        ? 'در این صفحه از فهرست بازبینی، عنوان مستقلی وجود ندارد.'
                                        : 'No independent articles on this review page.')
                                  : (fa
                                        ? 'مقاله منتشرشده‌ای در این صفحه موجود نیست.'
                                        : 'No published articles on this page.'),
                            ),
                          ),
                        for (final item in unique)
                          Card(
                            child: ListTile(
                              title: Text('${item['title'] ?? ''}'),
                              subtitle: Text(
                                [
                                  if (item['country_codes'] is List &&
                                      (item['country_codes'] as List)
                                          .isNotEmpty)
                                    (item['country_codes'] as List)
                                        .whereType<String>()
                                        .map(
                                          (code) => editorialCountryName(
                                            code,
                                            locale,
                                          ),
                                        )
                                        .join(' · ')
                                  else
                                    fa ? 'عمومی' : 'General',
                                  if (item['source_publishers'] is List)
                                    (item['source_publishers'] as List)
                                        .whereType<String>()
                                        .join(' · '),
                                ].where((value) => value.isNotEmpty).join('\n'),
                              ),
                              trailing: const Icon(Icons.menu_book_outlined),
                              onTap: () => context.push(
                                '/visa/content/${item['id']}?locale=$locale${widget.preview ? '&preview=true' : ''}',
                              ),
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: positions.length < 2
                                  ? null
                                  : () => setState(positions.removeLast),
                              child: Text(fa ? 'قبلی' : 'Previous'),
                            ),
                            TextButton(
                              onPressed:
                                  data['has_more'] != true ||
                                      data['next_cursor'] is! String
                                  ? null
                                  : () => setState(
                                      () => positions.add(
                                        data['next_cursor'] as String,
                                      ),
                                    ),
                              child: Text(fa ? 'بعدی' : 'Next'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}
