import 'package:flutter/material.dart';

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
    return true;
  }

  String _language(String code) => code == 'fa' ? 'فارسی (fa)' : 'English (en)';

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
        SelectableText(
          evidence['${prefix}_fragment'] as String,
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
