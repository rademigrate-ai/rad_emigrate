import 'package:flutter/material.dart';

import '../../../visa/data/editorial_repository.dart';
import '../../../visa/presentation/widgets/editorial_rich_block.dart';

/// Source-aware reading view. Mechanical merge decisions are explained without
/// creating approval tasks; publication remains a separate server operation.
class EditorialCompositionReview extends StatelessWidget {
  const EditorialCompositionReview({
    super.key,
    required this.composition,
    required this.locale,
  });
  final Map<String, dynamic> composition;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final fa = locale == 'fa';
    final sections = editorialRows(composition['sections']);
    final omissions = editorialRows(composition['omissions']);
    final conflicts = editorialRows(composition['conflicts']);
    return Directionality(
      textDirection: fa ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              fa
                  ? 'متن ترکیبی و منشأ بندها'
                  : 'Composed body and passage sources',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (sections.isEmpty)
              Text(
                fa
                    ? 'متن ساختاریافته برای این نسخه در دسترس نیست.'
                    : 'Structured content is unavailable for this revision.',
              ),
            for (final section in sections)
              ExpansionTile(
                title: Text('${section['heading'] ?? ''}'),
                subtitle: Text(
                  fa
                      ? '${editorialRows(section['blocks']).length} بند'
                      : '${editorialRows(section['blocks']).length} passages',
                ),
                children: [
                  for (final block in editorialRows(section['blocks']))
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: BorderDirectional(
                          start: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          ),
                        ),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (block['source_role'] != null ||
                              block['passage_classification'] != null)
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (block['source_role'] != null)
                                  Chip(
                                    label: Text(
                                      block['source_role'] == 'supplemental'
                                          ? (fa
                                                ? 'منبع تکمیلی'
                                                : 'Supplemental source')
                                          : (fa
                                                ? 'منبع اولویت‌دار'
                                                : 'Primary source'),
                                    ),
                                  ),
                                if (block['passage_classification'] != null)
                                  Chip(
                                    label: Text(
                                      switch (block['passage_classification']) {
                                        'specialist_medical' =>
                                          fa
                                              ? 'محتوای تخصصی پزشکی'
                                              : 'Specialist medical content',
                                        'mixed_uncertain' =>
                                          fa
                                              ? 'محتوای ترکیبی یا نامطمئن'
                                              : 'Mixed or uncertain content',
                                        _ =>
                                          fa
                                              ? 'اطلاعات عمومی'
                                              : 'General information',
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          EditorialRichBlock(block: block),
                          if (block['selected_origin'] is Map)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SelectableText(
                                '${fa ? 'متن انتخاب‌شده از' : 'Selected wording from'}: ${(block['selected_origin'] as Map)['publisher'] ?? ''}\n${(block['selected_origin'] as Map)['url'] ?? ''}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                          if (block['id'] is String)
                            SelectableText(
                              '${fa ? 'شناسه بند' : 'Passage'}: ${block['id']}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          for (final source in editorialRows(
                            block['provenance'],
                          ))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SelectableText(
                                [
                                  '${source['publisher'] ?? Uri.tryParse('${source['url']}')?.host ?? ''}',
                                  '${source['url'] ?? ''}',
                                  if (source['role'] != null)
                                    '${source['role']}',
                                  if (source['snapshot_id'] != null)
                                    '${fa ? 'نسخه منبع' : 'Snapshot'}: ${source['snapshot_id']}',
                                  if (source['sha256'] != null)
                                    'SHA-256: ${source['sha256']}',
                                ].where((line) => line.isNotEmpty).join('\n'),
                                textDirection: TextDirection.ltr,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            if (omissions.isNotEmpty)
              ExpansionTile(
                title: Text(
                  fa
                      ? 'بندهای تکراری با معادل نگه‌داشته‌شده (${omissions.length})'
                      : 'Duplicates represented by retained passages (${omissions.length})',
                ),
                children: [
                  for (final omission in omissions)
                    ListTile(
                      title: Text('${omission['reason'] ?? ''}'),
                      subtitle: SelectableText(
                        [
                          '${fa ? 'معادل نگه‌داشته‌شده' : 'Retained equivalent'}: ${omission['represented_block_id'] ?? ''}',
                          if (omission['provenance'] is Map)
                            '${(omission['provenance'] as Map)['url'] ?? ''}',
                        ].join('\n'),
                      ),
                    ),
                ],
              ),
            if (conflicts.isNotEmpty)
              ExpansionTile(
                title: Text(
                  fa
                      ? 'اختلاف‌های ثبت‌شده (${conflicts.length})'
                      : 'Recorded disagreements (${conflicts.length})',
                ),
                children: [
                  for (final conflict in conflicts)
                    ListTile(
                      leading: const Icon(Icons.compare_arrows),
                      title: Text(
                        '${conflict['heading'] ?? conflict['type'] ?? ''}',
                      ),
                      subtitle: SelectableText(
                        [
                          '${conflict['resolution'] ?? ''}',
                          if (conflict['source_values'] is Map)
                            for (final entry
                                in (conflict['source_values'] as Map).entries)
                              '${entry.key}: ${entry.value is List ? (entry.value as List).join(', ') : entry.value}',
                        ].where((line) => line.isNotEmpty).join('\n'),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
