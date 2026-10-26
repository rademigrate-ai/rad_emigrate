import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                    if (targetBlock != null && block['id'] == targetBlock) {
                      targetIndex = children.length;
                    }
                    if (block['id'] is String) {
                      blockPositions[block['id'] as String] = children.length;
                    }
                    children.add(EditorialRichBlock(block: block));
                  }
                }
                final sources = editorialRows(data['sources']);
                final references = editorialRows(data['reference_links']);
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
                  final url = reference['url'] as String? ?? '';
                  final uri = Uri.tryParse(url);
                  if (uri == null ||
                      !{'http', 'https'}.contains(uri.scheme) ||
                      !seenReferences.add(url)) {
                    continue;
                  }
                  final target = blockPositions[reference['target_block_id']];
                  children.add(
                    TextButton(
                      onPressed: () => target == null
                          ? launchUrl(uri, mode: LaunchMode.externalApplication)
                          : bodyController.seekTo(target),
                      child: Text(
                        (reference['label'] as String? ?? '').isEmpty
                            ? url
                            : '${reference['label']} — $url',
                      ),
                    ),
                  );
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
