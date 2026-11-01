import 'package:flutter/material.dart';

import 'source_change_diff.dart';

/// Verbatim source evidence is separate from the article's language and text.
/// This panel renders plain, selectable text; it never translates source data.
class BoundSourceEvidencePanel extends StatelessWidget {
  const BoundSourceEvidencePanel({
    super.key,
    required this.evidence,
    required this.isPersian,
  });

  final Map<String, dynamic> evidence;
  final bool isPersian;

  static bool isValid(Object? value) {
    if (value is! Map) return false;
    final url = value['source_url'];
    final uri = url is String ? Uri.tryParse(url) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        url is! String ||
        url.length > 2048) {
      return false;
    }
    if (!['en', 'fa'].contains(value['source_language']) ||
        !['en', 'fa'].contains(value['article_locale'])) {
      return false;
    }
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    final hash = RegExp(r'^[0-9a-f]{64}$');
    for (final prefix in ['old', 'new']) {
      final snapshot = value['${prefix}_snapshot_id'];
      final contentHash = value['${prefix}_content_hash'];
      final fragment = value['${prefix}_fragment'];
      if (snapshot is! String ||
          !uuid.hasMatch(snapshot) ||
          contentHash is! String ||
          !hash.hasMatch(contentHash) ||
          fragment is! String ||
          fragment.trim().isEmpty ||
          fragment.runes.length > 4000) {
        return false;
      }
    }
    if (value.containsKey('review_metadata')) {
      final metadata = value['review_metadata'];
      if (metadata is! Map ||
          metadata['context_scope'] !=
              'current_registry_context_not_capture_verification' ||
          metadata['uncertainty_code'] != 'human_legal_review_required' ||
          metadata['change_classification'] != 'bound_source_text_change' ||
          !metadata.containsKey('source_published_at') ||
          !metadata.containsKey('effective_date') ||
          metadata['source_published_at'] != null ||
          metadata['effective_date'] != null) {
        return false;
      }
      for (final key in ['publisher_name', 'jurisdiction', 'authority_state']) {
        final entry = metadata[key];
        if (!metadata.containsKey(key) ||
            (entry != null &&
                (entry is! String ||
                    entry.trim().isEmpty ||
                    entry.length > 300))) {
          return false;
        }
      }
      for (final key in ['old_fetched_at', 'new_fetched_at']) {
        final entry = metadata[key];
        if (!metadata.containsKey(key) ||
            (entry != null &&
                (entry is! String ||
                    entry.length > 50 ||
                    !RegExp(r'^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$')
                        .hasMatch(entry) ||
                    DateTime.tryParse(entry) == null))) {
          return false;
        }
      }
    }
    return true;
  }

  String _language(String code) => code == 'fa' ? 'فارسی (fa)' : 'English (en)';

  Widget _reviewMetadata(BuildContext context, Map metadata) {
    final unknown = isPersian
        ? 'در این شاهد مشخص نشده است'
        : 'Not established by this evidence';
    String entry(String key) => metadata[key] as String? ?? unknown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        Text(
          isPersian
              ? 'اطلاعات فعلی مرجع — تأیید این ثبت منبع نیست'
              : 'Current registry context — not verification of this capture',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text('${isPersian ? 'ناشر' : 'Publisher'}: ${entry('publisher_name')}'),
        Text(
          '${isPersian ? 'حوزه صلاحیت' : 'Jurisdiction'}: ${entry('jurisdiction')}',
        ),
        Text(
          '${isPersian ? 'وضعیت فعلی مرجع' : 'Current registry state'}: ${entry('authority_state')}',
        ),
        Text(
          '${isPersian ? 'زمان ثبت قبلی' : 'Previous capture time'}: ${entry('old_fetched_at')}',
        ),
        Text(
          '${isPersian ? 'زمان ثبت جدید' : 'New capture time'}: ${entry('new_fetched_at')}',
        ),
        Text(
          '${isPersian ? 'تاریخ انتشار منبع' : 'Source publication date'}: $unknown',
        ),
        Text('${isPersian ? 'تاریخ اجرا' : 'Effective date'}: $unknown'),
        const SizedBox(height: 8),
        Text(
          isPersian
              ? 'متن منبع تغییر کرده است؛ معنای حقوقی آن نیازمند بازبینی انسانی است.'
              : 'Source text changed; legal meaning requires human review.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sourceDirection = evidence['source_language'] == 'fa'
        ? TextDirection.rtl
        : TextDirection.ltr;
    Widget snapshot(String prefix, String title) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        SourceChangeText(
          before: evidence['old_fragment'] as String,
          after: evidence['new_fragment'] as String,
          showBefore: prefix == 'old',
          isPersian: isPersian,
          textDirection: sourceDirection,
        ),
        const SizedBox(height: 8),
        Text(isPersian ? 'شناسه کپسول منبع' : 'Source snapshot ID'),
        SelectableText(
          evidence['${prefix}_snapshot_id'] as String,
          textDirection: TextDirection.ltr,
        ),
        const SizedBox(height: 4),
        const Text('SHA-256'),
        SelectableText(
          evidence['${prefix}_content_hash'] as String,
          textDirection: TextDirection.ltr,
        ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isPersian
                  ? 'متن اصلی منبع — ترجمه نشده'
                  : 'Original source text — not translated',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isPersian
                  ? 'متن حذف‌شده خط خورده و متن افزوده‌شده زیرخط‌دار است.'
                  : 'Removed text is crossed out; added text is underlined.',
            ),
            const SizedBox(height: 8),
            Text(
              isPersian
                  ? 'این نقل‌قول، شاهد پیشنهادی برای بازبینی است و تأیید حقوقی نشده است.'
                  : 'This quotation is proposed evidence for review and has not been legally verified.',
            ),
            const SizedBox(height: 8),
            Text(
              '${isPersian ? 'زبان منبع' : 'Source language'}: ${_language(evidence['source_language'] as String)}',
            ),
            Text(
              '${isPersian ? 'زبان مقاله' : 'Article language'}: ${_language(evidence['article_locale'] as String)}',
            ),
            const SizedBox(height: 8),
            SelectableText(
              evidence['source_url'] as String,
              textDirection: TextDirection.ltr,
            ),
            if (evidence['review_metadata'] is Map)
              _reviewMetadata(context, evidence['review_metadata'] as Map),
            const Divider(height: 24),
            snapshot(
              'old',
              isPersian ? 'متن قبلی منبع' : 'Previous source fragment',
            ),
            const Divider(height: 24),
            snapshot(
              'new',
              isPersian ? 'متن جدید منبع' : 'New source fragment',
            ),
          ],
        ),
      ),
    );
  }
}
