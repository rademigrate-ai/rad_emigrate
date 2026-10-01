import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/document.dart';
import '../../domain/entities/document_type.dart';
import '../providers/document_controller.dart';

class DocumentsPage extends ConsumerWidget {
  const DocumentsPage({super.key});

  Color _statusColor(DocumentVerificationStatus s) {
    switch (s) {
      case DocumentVerificationStatus.missing:
        return Colors.grey;
      case DocumentVerificationStatus.uploaded:
        return Colors.blue;
      case DocumentVerificationStatus.underReview:
        return Colors.orange;
      case DocumentVerificationStatus.verified:
        return Colors.green;
      case DocumentVerificationStatus.rejected:
        return AppColors.primaryRed;
    }
  }

  IconData _statusIcon(DocumentVerificationStatus s) {
    switch (s) {
      case DocumentVerificationStatus.missing:
        return Icons.hourglass_empty;
      case DocumentVerificationStatus.uploaded:
        return Icons.cloud_upload_outlined;
      case DocumentVerificationStatus.underReview:
        return Icons.pending_actions;
      case DocumentVerificationStatus.verified:
        return Icons.verified;
      case DocumentVerificationStatus.rejected:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(documentControllerProvider.notifier).load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add type'),
        onPressed: () async {
          await ref.read(documentControllerProvider.notifier).addPlaceholder(
                name: 'New document',
                kind: DocumentTypeKind.other,
              );
        },
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$e'),
              TextButton(
                onPressed: () => ref.read(documentControllerProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (docs) {
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    _statusIcon(doc.status),
                    color: _statusColor(doc.status),
                  ),
                  title: Text(doc.name),
                  subtitle: Text('${doc.kind.label} · ${doc.status.label}'),
                  trailing: Chip(
                    label: Text(
                      doc.status.label,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    backgroundColor: _statusColor(doc.status),
                    visualDensity: VisualDensity.compact,
                  ),
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (ctx) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(doc.name, style: Theme.of(ctx).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text('Type: ${doc.kind.label}'),
                            Text('Status: ${doc.status.label}'),
                            if (doc.updatedAt != null)
                              Text(
                                'Updated: ${doc.updatedAt!.toIso8601String().substring(0, 10)}',
                              ),
                            const SizedBox(height: 16),
                            const Text(
                              'Upload is simulated offline. No file is sent to a server. '
                              'OCR and AI analysis will connect in a future release.',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            if (doc.status == DocumentVerificationStatus.missing ||
                                doc.status == DocumentVerificationStatus.rejected)
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primaryRed,
                                ),
                                onPressed: () async {
                                  await ref
                                      .read(documentControllerProvider.notifier)
                                      .markUploaded(
                                        doc.id,
                                        fileName: '${doc.name} (uploaded)',
                                      );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Mark as uploaded'),
                              ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
