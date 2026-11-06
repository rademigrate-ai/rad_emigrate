import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../l10n/app_localizations.dart';

class DocumentDeletionStatus {
  const DocumentDeletionStatus({required this.id, required this.state});
  final String id;
  final String state;
}

final documentDeletionStatusProvider =
    FutureProvider<List<DocumentDeletionStatus>>((ref) async {
      final userId = ref.watch(authenticatedUserIdProvider);
      final service = ref.watch(supabaseClientServiceProvider);
      if (userId == null || !service.isInitialized) return [];
      final response = await service.client.rpc('list_document_deletions');
      if (response is! List) {
        throw const FormatException('Invalid deletion status');
      }
      final statuses = <DocumentDeletionStatus>[];
      for (final row in response) {
        if (row is! Map || row['owner_id'] != userId) continue;
        final state = row['state'];
        final id = row['document_id'];
        if (id is! String ||
            state is! String ||
            !{
              'pending_storage',
              'retrying',
              'failed',
              'finalized',
            }.contains(state)) {
          throw const FormatException('Invalid deletion status');
        }
        statuses.add(DocumentDeletionStatus(id: id, state: state));
      }
      if (statuses.any(
        (item) => item.state == 'pending_storage' || item.state == 'retrying',
      )) {
        final timer = Timer(const Duration(seconds: 5), ref.invalidateSelf);
        ref.onDispose(timer.cancel);
      }
      return statuses;
    });

class DocumentDeletionStatusPanel extends ConsumerWidget {
  const DocumentDeletionStatusPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(documentDeletionStatusProvider);
    return status.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => ListTile(
        title: Text(l10n.documentDeletionStatusUnavailable),
        trailing: IconButton(
          tooltip: l10n.refresh,
          onPressed: () => ref.invalidate(documentDeletionStatusProvider),
          icon: const Icon(Icons.refresh),
        ),
      ),
      data: (items) => items.isEmpty
          ? const SizedBox.shrink()
          : ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.28,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        leading: Icon(switch (item.state) {
                          'finalized' => Icons.check_circle_outline,
                          'failed' => Icons.error_outline,
                          _ => Icons.hourglass_empty,
                        }),
                        title: Text(switch (item.state) {
                          'finalized' => l10n.documentDeletionComplete,
                          'failed' => l10n.documentDeletionFailed,
                          'retrying' => l10n.documentDeletionRetrying,
                          _ => l10n.documentDeletionPending,
                        }),
                        subtitle: Text(
                          '${l10n.documentDeletionReference}: ${item.id}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
