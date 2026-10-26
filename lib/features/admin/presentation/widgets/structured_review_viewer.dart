import 'package:flutter/material.dart';

import '../../../visa/presentation/widgets/editorial_rich_block.dart';
import '../../domain/structured_review.dart';

/// Shows every base block in order. Decisions are keyed by immutable patch ID.
class StructuredReviewViewer extends StatelessWidget {
  const StructuredReviewViewer({
    super.key,
    required this.sections,
    required this.patches,
    required this.decisions,
    required this.edits,
    required this.onAction,
    required this.onEdit,
    required this.isPersian,
  });
  final List<dynamic> sections;
  final List<dynamic> patches;
  final Map<String, String> decisions;
  final Map<String, String> edits;
  final void Function(String, String) onAction;
  final void Function(String, String) onEdit;
  final bool isPersian;

  Future<void> _edit(BuildContext context, Map<String, dynamic> patch) async {
    final id = patch['id'] as String;
    final controller = TextEditingController(
      text: edits[id] ?? patch['text'] as String? ?? '',
    );
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPersian ? 'ویرایش متن پیشنهادی' : 'Edit suggested text'),
        content: SizedBox(
          width: 600,
          child: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 12,
            maxLength: 20000,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isPersian ? 'انصراف' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: Text(isPersian ? 'ذخیره ویرایش' : 'Use edit'),
          ),
        ],
      ),
    );
    // Dialog closing animation can still reference its controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (text != null && context.mounted) onEdit(id, text);
  }

  @override
  Widget build(BuildContext context) {
    final byBlock = {for (final p in patches) (p as Map)['block_id']: p};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isPersian
              ? 'مقایسه کامل صفحه — منتشرنشده'
              : 'Complete page comparison — unpublished',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          isPersian
              ? 'شواهد پیشنهادی به معنی تأیید رسمی نیست.'
              : 'Candidate evidence is not official verification.',
        ),
        for (final section in sections) ...[
          Text(
            (section as Map)['heading'] as String? ?? '',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final raw in section['blocks'] as List)
            _block(
              context,
              Map<String, dynamic>.from(raw as Map),
              byBlock[raw['id']] == null
                  ? null
                  : Map<String, dynamic>.from(byBlock[raw['id']] as Map),
            ),
        ],
      ],
    );
  }

  Widget _block(
    BuildContext context,
    Map<String, dynamic> block,
    Map<String, dynamic>? patch,
  ) {
    if (patch == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isPersian ? 'بدون تغییر' : 'Unchanged'),
          EditorialRichBlock(block: block),
        ],
      );
    }
    final id = patch['id'] as String;
    final rejected = decisions[id] == 'rejected';
    final operation = patch['operation'];
    final before = EditorialRichBlock(block: block);
    final after = rejected
        ? before
        : operation == 'remove'
        ? Text(
            isPersian
                ? 'حذف پیشنهادی این بخش'
                : 'This block is proposed for removal',
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (operation == 'add_after') before,
              EditorialRichBlock(
                block: previewRichBlock(block, patch, editedText: edits[id]),
              ),
            ],
          );
    final evidence = patch['evidence'] as Map;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${operation == 'remove'
                  ? (isPersian ? 'حذف' : 'Removed')
                  : operation == 'add_after'
                  ? (isPersian ? 'جدید' : 'Added')
                  : (isPersian ? 'تغییر' : 'Changed')} · ${rejected
                  ? (isPersian ? 'رد شده' : 'Rejected')
                  : decisions[id] == 'accepted'
                  ? (isPersian ? 'پذیرفته شده' : 'Accepted')
                  : (isPersian ? 'در انتظار تصمیم' : 'Decision required')}',
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                Widget panel(String label, Widget child) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    child,
                  ],
                );
                final left = panel(
                  isPersian ? 'نسخه فعلی' : 'Current revision',
                  before,
                );
                final right = panel(
                  isPersian ? 'پیش‌نویس پس از تصمیم' : 'Draft after decision',
                  after,
                );
                return constraints.maxWidth < 800
                    ? Column(children: [left, const Divider(), right])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: left),
                          const SizedBox(width: 20),
                          Expanded(child: right),
                        ],
                      );
              },
            ),
            Text(
              '${evidence['excerpt']}\n${evidence['locator']}\n${evidence['snapshot_id']}',
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => onAction(id, 'accept'),
                  child: Text(isPersian ? 'پذیرش' : 'Accept'),
                ),
                TextButton(
                  onPressed: () => onAction(id, 'reject'),
                  child: Text(isPersian ? 'رد' : 'Reject'),
                ),
                if (operation != 'remove')
                  TextButton(
                    onPressed: () => _edit(context, patch),
                    child: Text(isPersian ? 'ویرایش' : 'Edit'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
