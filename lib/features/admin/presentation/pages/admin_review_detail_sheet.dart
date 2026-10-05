import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/admin_operations_repository.dart';
import '../../data/admin_review_actions.dart';

/// Review detail + edit + reject / keep / approve / explicit publish.
Future<void> showAdminReviewDetail(
  BuildContext context,
  WidgetRef ref,
  AdminReviewRecord item,
) async {
  final l10n = AppLocalizations.of(context);
  final actions = ref.read(adminReviewActionsProvider);

  if (item.kind != 'draft') {
    // Findings: status only (no feed publish from finding alone).
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.reviewFindingTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(item.title),
                if ((item.summary ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(item.summary!),
                ],
                const SizedBox(height: 8),
                Text('${l10n.status}: ${item.status}'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        await actions.setFindingStatus(
                          findingId: item.id,
                          status: 'rejected',
                        );
                        if (context.mounted) Navigator.pop(context);
                        ref.invalidate(adminConsoleProvider);
                      },
                      child: Text(l10n.reject),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        await actions.setFindingStatus(
                          findingId: item.id,
                          status: 'review',
                        );
                        if (context.mounted) Navigator.pop(context);
                        ref.invalidate(adminConsoleProvider);
                      },
                      child: Text(l10n.keepPending),
                    ),
                    FilledButton(
                      onPressed: () async {
                        await actions.setFindingStatus(
                          findingId: item.id,
                          status: 'approved',
                        );
                        if (context.mounted) Navigator.pop(context);
                        ref.invalidate(adminConsoleProvider);
                      },
                      child: Text(l10n.approve),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.findingPublishNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
    return;
  }

  final detail = await actions.loadDraftDetail(item.id);
  if (!context.mounted) return;

  final titleCtrl = TextEditingController(
    text: detail?['title'] as String? ?? item.title,
  );
  final bodyCtrl = TextEditingController(
    text: detail?['body'] as String? ?? item.summary ?? '',
  );
  var language = detail?['language_code'] as String? ?? 'en';
  var category = detail?['category'] as String? ?? 'update';
  var busy = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> run(Future<void> Function() op) async {
            if (busy) return;
            setState(() => busy = true);
            try {
              await op();
              if (context.mounted) Navigator.pop(context);
              ref.invalidate(adminConsoleProvider);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.errorGeneric)),
                );
              }
            } finally {
              if (context.mounted) setState(() => busy = false);
            }
          }

          final bottom = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.reviewDraftTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(labelText: l10n.editTitle),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyCtrl,
                    minLines: 4,
                    maxLines: 10,
                    decoration: InputDecoration(labelText: l10n.editBody),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: language,
                    decoration: InputDecoration(labelText: l10n.language),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('EN')),
                      DropdownMenuItem(value: 'fa', child: Text('FA')),
                    ],
                    onChanged: busy
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => language = value);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: InputDecoration(labelText: l10n.category),
                    items: const [
                      DropdownMenuItem(value: 'update', child: Text('update')),
                      DropdownMenuItem(value: 'guide', child: Text('guide')),
                      DropdownMenuItem(
                        value: 'deadline',
                        child: Text('deadline'),
                      ),
                      DropdownMenuItem(value: 'event', child: Text('event')),
                      DropdownMenuItem(
                        value: 'announcement',
                        child: Text('announcement'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => category = value);
                            }
                          },
                  ),
                  if (detail?['source_url'] != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.source,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: SelectableText(
                        '${detail!['source_url']}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => run(
                                  () => actions.setDraftStatus(
                                    draftId: item.id,
                                    status: 'rejected',
                                  ),
                                ),
                        child: Text(l10n.reject),
                      ),
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => run(
                                  () => actions.setDraftStatus(
                                    draftId: item.id,
                                    status: 'review',
                                  ),
                                ),
                        child: Text(l10n.keepPending),
                      ),
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                  await actions.updateDraft(
                                    draftId: item.id,
                                    title: titleCtrl.text.trim(),
                                    body: bodyCtrl.text.trim(),
                                    languageCode: language,
                                    category: category,
                                  );
                                  await actions.setDraftStatus(
                                    draftId: item.id,
                                    status: 'approved',
                                  );
                                }),
                        child: Text(l10n.approve),
                      ),
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                  await actions.updateDraft(
                                    draftId: item.id,
                                    title: titleCtrl.text.trim(),
                                    body: bodyCtrl.text.trim(),
                                    languageCode: language,
                                    category: category,
                                  );
                                  await actions.publishDraft(
                                    draftId: item.id,
                                    category: category,
                                  );
                                }),
                        child: Text(l10n.publishExplicit),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.publishRequiresHuman,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  titleCtrl.dispose();
  bodyCtrl.dispose();
}
