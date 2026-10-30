import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../data/editorial_repository.dart';
import '../widgets/editorial_rich_block.dart';
import '../widgets/other_titles.dart';
import '../widgets/editorial_scroll_body.dart';

class EditorialArticlePage extends ConsumerWidget {
  const EditorialArticlePage({
    super.key,
    required this.articleId,
    required this.locale,
    this.preview = false,
    this.initialSectionAnchor,
    this.requestedLocale,
  });
  final String articleId;
  final String locale;
  final bool preview;
  final String? initialSectionAnchor;
  final String? requestedLocale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (id: articleId, locale: locale, preview: preview);
    return Directionality(
      textDirection: locale == 'fa' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallback: '/visa'),
          title: Text(
            preview
                ? (locale == 'fa' ? 'پیش‌نمایش سردبیری' : 'Editorial preview')
                : (locale == 'fa' ? 'ویزا' : 'Visa'),
          ),
        ),
        body: ref
            .watch(editorialArticleProvider(key))
            .when(
              loading: () => Center(
                child: RadLoadingIndicator(
                  label: locale == 'fa'
                      ? 'در حال دریافت محتوا'
                      : 'Loading content',
                ),
              ),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      locale == 'fa'
                          ? 'محتوا یا ترجمه در دسترس نیست.'
                          : 'Content or translation is unavailable.',
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(editorialArticleProvider(key)),
                      child: Text(locale == 'fa' ? 'تلاش دوباره' : 'Retry'),
                    ),
                  ],
                ),
              ),
              data: (data) {
                final sections = editorialRows(
                  data['rich_sections'] ?? data['sections'],
                );
                final bodyController = EditorialBodyController();
                final blockPositions = <String, int>{};
                final children = <Widget>[
                  Semantics(
                    header: true,
                    child: SelectableText(
                      data['title'] as String? ?? '',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  if (preview)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        locale == 'fa'
                            ? 'پیش‌نویس تأییدنشده — قابل انتشار عمومی نیست'
                            : 'Unverified draft — public publication is blocked',
                      ),
                    ),
                ];
                if (requestedLocale != null && requestedLocale != locale) {
                  children.insert(
                    0,
                    Text(
                      requestedLocale == 'fa'
                          ? 'ترجمه فارسی در دسترس نیست؛ متن اصلی انگلیسی نمایش داده می‌شود.'
                          : 'The requested translation is unavailable. The original source language is shown.',
                    ),
                  );
                }
                String? targetBlock;
                for (final mapping in editorialRows(data['projection_map'])) {
                  if (mapping['anchor'] == initialSectionAnchor ||
                      mapping['section_id'] == initialSectionAnchor) {
                    targetBlock = mapping['first_rich_block_id'] as String?;
                  }
                }
                int? targetIndex;
                String? lastProgram;
                for (final section in sections) {
                  final blocks = editorialRows(section['blocks']);
                  final program = section['program'] as String?;
                  const scopes = {
                    'nursing': ['پرستاری', 'Nursing'],
                    'dentistry': ['دندان‌پزشکی', 'Dentistry'],
                    'pharmacy': ['داروسازی', 'Pharmacy'],
                    'medicine': ['پزشکی', 'Medicine'],
                    'school': ['مدرسه', 'School'],
                    'doctoral': ['دکتری', 'Doctoral studies'],
                    'job-seeker': ['جست‌وجوی کار', 'Job seeking'],
                    'blue-card': ['کارت آبی', 'Blue Card'],
                    'startup': ['استارتاپ', 'Startup'],
                    'self-employed': ['خوداشتغالی', 'Self-employment'],
                  };
                  if (program != lastProgram && scopes.containsKey(program)) {
                    children.add(
                      Semantics(
                        header: true,
                        child: Text(
                          scopes[program]![locale == 'fa' ? 0 : 1],
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    );
                  }
                  lastProgram = program;
                  if (initialSectionAnchor != null &&
                      (section['anchor'] == initialSectionAnchor ||
                          section['id'] == initialSectionAnchor)) {
                    targetIndex = children.length;
                  }
                  if (blocks.isEmpty ||
                      blocks.first['type'] != 'heading' ||
                      blocks.first['text'] != section['heading']) {
                    children.add(
                      Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 8),
                        child: Semantics(
                          header: true,
                          child: SelectableText(
                            '${section['heading'] ?? ''}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                    );
                  }
                  for (final block in blocks) {
                    if ((targetBlock != null && block['id'] == targetBlock) ||
                        (initialSectionAnchor != null &&
                            block['id'] == initialSectionAnchor)) {
                      targetIndex = children.length;
                    }
                    if (block['id'] is String) {
                      blockPositions[block['id'] as String] = children.length;
                    }
                    children.add(EditorialRichBlock(block: block));
                  }
                }
                final sources = editorialRows(data['sources']);
                final composition = data['composition'] is Map
                    ? data['composition'] as Map
                    : const {};
                final references = [
                  ...editorialRows(data['reference_links']),
                  ...editorialRows(
                    data['source_links'] ??
                        composition['source_links'] ??
                        composition['body_links'],
                  ),
                ];
                final assets = editorialRows(
                  data['source_assets'] ?? composition['source_assets'],
                );
                if (assets.isNotEmpty) {
                  children.add(
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        locale == 'fa' ? 'رسانه‌های منبع' : 'Source media',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  );
                  final seenAssets = <String>{};
                  for (final asset in assets) {
                    final url = asset['url'];
                    // The same image may have distinct meaningful captions.
                    // URL equality alone must not silently discard those.
                    final identity =
                        '$url\u0000${asset['kind']}\u0000${asset['alt']}\u0000${asset['caption']}';
                    if (url is! String || !seenAssets.add(identity)) continue;
                    children.add(
                      EditorialRichBlock(
                        block: {
                          ...asset,
                          'type': asset['kind'] == 'img'
                              ? 'image'
                              : asset['kind'] ?? 'media',
                        },
                      ),
                    );
                  }
                }
                if (sources.isNotEmpty || references.isNotEmpty) {
                  children.add(
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        locale == 'fa' ? 'منابع' : 'Sources',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  );
                  final seen = <String>{};
                  for (final source in sources) {
                    final url = source['url'] as String? ?? '';
                    final uri = Uri.tryParse(url);
                    if (uri != null &&
                        ['http', 'https'].contains(uri.scheme) &&
                        seen.add(url)) {
                      children.add(
                        TextButton(
                          onPressed: () => launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          ),
                          child: Text(
                            '${source['publisher'] ?? uri.host}\n$url',
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                      );
                    }
                  }
                  children.add(
                    Text(
                      locale == 'fa'
                          ? 'تاریخ دریافت منبع، تاریخ تأیید حقوقی نیست.'
                          : 'Source retrieval dates are not legal verification dates.',
                    ),
                  );
                }
                final seenReferences = <String>{};
                for (final reference in references) {
                  final url =
                      reference['original_url'] as String? ??
                      reference['url'] as String? ??
                      '';
                  final uri = Uri.tryParse(url);
                  if (uri == null ||
                      !{'http', 'https'}.contains(uri.scheme) ||
                      uri.host.isEmpty ||
                      uri.userInfo.isNotEmpty ||
                      !seenReferences.add(url)) {
                    continue;
                  }
                  final target = blockPositions[reference['target_block_id']];
                  final appId = reference['app_article_id'];
                  final internal =
                      preview &&
                      appId is String &&
                      RegExp(
                        r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
                      ).hasMatch(appId);
                  final targetLocale = reference['app_locale'] == 'en'
                      ? 'en'
                      : reference['app_locale'] == 'fa'
                      ? 'fa'
                      : locale;
                  final internalUri = internal
                      ? Uri(
                          path: '/visa/content/$appId',
                          queryParameters: {
                            'locale': targetLocale,
                            'preview': 'true',
                            if (targetLocale != locale)
                              'requested_locale': locale,
                          },
                          fragment: reference['app_fragment'] is String
                              ? reference['app_fragment'] as String
                              : null,
                        )
                      : null;
                  final label = (reference['label'] as String? ?? '').isEmpty
                      ? url
                      : reference['label'] as String;
                  children.add(
                    TextButton(
                      onPressed: () {
                        if (internalUri != null) {
                          context.push(internalUri.toString());
                        } else if (target != null) {
                          bodyController.seekTo(target);
                        } else {
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Text(
                        internalUri != null
                            ? '$label — ${locale == 'fa' ? 'خواندن در راد' : 'Read in RAD'}'
                            : label == url
                            ? url
                            : '$label — $url',
                      ),
                    ),
                  );
                  if (internalUri != null) {
                    children.add(
                      TextButton.icon(
                        onPressed: () => launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                          '${locale == 'fa' ? 'منبع اصلی' : 'Original source'} — $url',
                        ),
                      ),
                    );
                  }
                }
                if (data['references_capture_status'] == 'unavailable') {
                  children.add(
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(editorialArticleProvider(key)),
                      child: Text(
                        locale == 'fa'
                            ? 'دریافت دوباره ارجاعات اصلی'
                            : 'Retry original references',
                      ),
                    ),
                  );
                }
                children.add(
                  OtherTitles(
                    items: editorialRows(
                      data['other_titles'] ?? data['related_articles'],
                    ),
                    locale: locale,
                    preview: preview,
                  ),
                );
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: EditorialScrollBody(
                      bodyController: bodyController,
                      key: ValueKey(
                        '${data['revision_id'] ?? articleId}:$locale:$initialSectionAnchor',
                      ),
                      targetIndex: targetIndex,
                      children: children,
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}

class EditorialLegacySlugPage extends ConsumerWidget {
  const EditorialLegacySlugPage({
    super.key,
    required this.country,
    required this.slug,
  });
  final String country;
  final String slug;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).languageCode == 'fa'
        ? 'fa'
        : 'en';
    final key = (country: country, slug: slug, locale: locale);
    return ref
        .watch(editorialSlugProvider(key))
        .when(
          data: (id) => EditorialArticlePage(articleId: id, locale: locale),
          loading: () => Scaffold(
            body: Center(
              child: RadLoadingIndicator(
                label: locale == 'fa'
                    ? 'در حال دریافت محتوا'
                    : 'Loading content',
              ),
            ),
          ),
          error: (_, _) => Scaffold(
            appBar: AppBar(leading: const AppBackButton(fallback: '/visa')),
            body: Center(
              child: TextButton(
                onPressed: () => ref.invalidate(editorialSlugProvider(key)),
                child: Text(
                  locale == 'fa'
                      ? 'محتوا یا ترجمه در دسترس نیست؛ تلاش دوباره'
                      : 'Content or translation unavailable; retry',
                ),
              ),
            ),
          ),
        );
  }
}
