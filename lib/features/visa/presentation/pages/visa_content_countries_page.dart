import 'package:flutter/material.dart';

import '../../../../core/widgets/directional_icons.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../data/editorial_repository.dart';
import '../widgets/country_visa_content.dart';
import '../../domain/editorial_country_names.dart';

class VisaContentCountriesPage extends ConsumerWidget {
  const VisaContentCountriesPage({
    super.key,
    this.countryCode,
    this.preview = false,
  });
  final String? countryCode;
  final bool preview;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).languageCode == 'fa'
        ? 'fa'
        : 'en';
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: locale == 'fa' ? 'دیگر عناوین' : 'Other Titles',
            icon: const Icon(Icons.library_books_outlined),
            onPressed: () => context.push(
              '/visa/other-titles${preview ? '?preview=true' : ''}',
            ),
          ),
        ],
        leading: const AppBackButton(fallback: '/visa'),
        title: Text(
          countryCode == null
              ? (locale == 'fa' ? 'کشورها' : 'Countries')
              : editorialCountryName(countryCode!, locale),
        ),
      ),
      body: countryCode != null
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: CountryVisaContent(
                countryCode: countryCode!,
                preview: preview,
              ),
            )
          : ref
                .watch(
                  preview
                      ? visaContentPreviewCountriesProvider(locale)
                      : visaContentCountriesProvider(locale),
                )
                .when(
                  loading: () => RadLoadingIndicator(
                    label: locale == 'fa'
                        ? 'در حال دریافت کشورها'
                        : 'Loading countries',
                  ),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(
                        preview
                            ? visaContentPreviewCountriesProvider(locale)
                            : visaContentCountriesProvider(locale),
                      ),
                      child: Text(
                        locale == 'fa'
                            ? 'دریافت دوباره کشورها'
                            : 'Retry countries',
                      ),
                    ),
                  ),
                  data: (items) => items.isEmpty
                      ? Center(
                          child: Text(
                            locale == 'fa'
                                ? 'محتوای ویزای تأییدشده و منتشرشده‌ای برای این زبان وجود ندارد.'
                                : 'No approved published Visa content is available in this language.',
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            for (final country in items)
                              Card(
                                child: ListTile(
                                  title: Text(
                                    editorialCountryName(
                                      country['country_code'] as String,
                                      locale,
                                    ),
                                  ),
                                  trailing: Icon(directionalForward(context)),
                                  onTap: () => context.push(
                                    '/visa/content-countries/${country['country_code']}${preview ? '?preview=true' : ''}',
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
    );
  }
}
