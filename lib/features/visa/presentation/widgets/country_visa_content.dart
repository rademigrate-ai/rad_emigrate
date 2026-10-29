import 'package:flutter/material.dart';

import '../../../../core/widgets/directional_icons.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/rad_loading.dart';
import '../../data/editorial_repository.dart';
import 'other_titles.dart';

class CountryVisaContent extends ConsumerWidget {
  const CountryVisaContent({
    super.key,
    required this.countryCode,
    this.preview = false,
    this.showCategories = true,
    this.showOtherTitles = true,
  });
  final String countryCode;
  final bool preview;
  final bool showCategories;
  final bool showOtherTitles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).languageCode == 'fa'
        ? 'fa'
        : 'en';
    final key = (country: countryCode, locale: locale, preview: preview);
    return ref
        .watch(countryVisaContentProvider(key))
        .when(
          loading: () => !showCategories
              ? const SizedBox.shrink()
              : RadLoadingIndicator(
                  size: RadLoadingSize.compact,
                  label: locale == 'fa'
                      ? 'در حال دریافت محتوا'
                      : 'Loading content',
                ),
          error: (_, _) => !showCategories
              ? const SizedBox.shrink()
              : TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    locale == 'fa'
                        ? 'دریافت دوباره محتوای ویزا'
                        : 'Retry Visa content',
                  ),
                  onPressed: () =>
                      ref.invalidate(countryVisaContentProvider(key)),
                ),
          data: (data) {
            final categories = editorialRows(data['categories']);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showCategories && categories.isNotEmpty) ...[
                  Text(
                    locale == 'fa' ? 'دسته‌بندی ویزا' : 'Visa categories',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final item in categories)
                    Card(
                      child: ListTile(
                        title: Text(item['title'] as String? ?? ''),
                        trailing: Icon(directionalForward(context)),
                        onTap: () => context.push(
                          '/visa/content/${item['id']}?locale=$locale${preview ? '&preview=true' : ''}',
                        ),
                      ),
                    ),
                ],
                if (showOtherTitles)
                  OtherTitles(
                    items: editorialRows(data['other_titles']),
                    locale: locale,
                    preview: preview,
                  ),
              ],
            );
          },
        );
  }
}
