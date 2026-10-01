import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/document.dart';
import '../../domain/entities/document_type.dart';
import '../providers/document_controller.dart';

class DocumentsPage extends ConsumerWidget {
  const DocumentsPage({super.key});

  StatusTone _tone(DocumentVerificationStatus s) {
    switch (s) {
      case DocumentVerificationStatus.missing:
        return StatusTone.warning;
      case DocumentVerificationStatus.uploaded:
        return StatusTone.info;
      case DocumentVerificationStatus.underReview:
        return StatusTone.warning;
      case DocumentVerificationStatus.verified:
        return StatusTone.success;
      case DocumentVerificationStatus.rejected:
        return StatusTone.danger;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(documentControllerProvider.notifier).load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add type'),
        onPressed: () async {
          await ref
              .read(documentControllerProvider.notifier)
              .addPlaceholder(
                name: 'New document',
                kind: DocumentTypeKind.other,
              );
        },
      ),
      body: state.when(
        loading: () => const LoadingState(message: 'Loading documents…'),
        error: (e, _) => ErrorState(
          message: '$e',
          onRetry: () => ref.read(documentControllerProvider.notifier).load(),
        ),
        data: (docs) {
          if (docs.isEmpty) {
            return EmptyState(
              title: 'No documents yet',
              subtitle: 'Add required document types for your case.',
              icon: Icons.folder_outlined,
            );
          }

          final missing = docs
              .where((d) => d.status == DocumentVerificationStatus.missing)
              .toList();
          final rest = docs
              .where((d) => d.status != DocumentVerificationStatus.missing)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
            children: [
              if (missing.isNotEmpty) ...[
                SectionHeader(
                  title: 'Missing',
                  subtitle: 'Upload these to continue your application',
                ),
                ...missing.map(
                  (doc) => _DocTile(
                    doc: doc,
                    tone: _tone(doc.status),
                    onTap: () => _openSheet(context, ref, doc),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SectionHeader(
                title: missing.isEmpty ? 'All documents' : 'Submitted',
              ),
              ...rest.map(
                (doc) => _DocTile(
                  doc: doc,
                  tone: _tone(doc.status),
                  onTap: () => _openSheet(context, ref, doc),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openSheet(BuildContext context, WidgetRef ref, Document doc) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(doc.name, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Type: ${doc.kind.label}'),
            Text('Status: ${doc.status.label}'),
            const SizedBox(height: 12),
            Text(
              'Accepted formats: PDF, JPG, JPEG, and PNG. Maximum size: 10 MB.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            if (doc.status == DocumentVerificationStatus.missing ||
                doc.status == DocumentVerificationStatus.rejected)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () async {
                  final result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
                    withData: true,
                  );
                  if (result == null || result.files.isEmpty) return;
                  final file = result.files.single;
                  final bytes = file.bytes;
                  if (bytes == null) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Could not read that file.'),
                        ),
                      );
                    }
                    return;
                  }
                  if (bytes.length > 10 * 1024 * 1024) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Files must be 10 MB or smaller.'),
                        ),
                      );
                    }
                    return;
                  }
                  final extension = (file.extension ?? '').toLowerCase();
                  final contentType = switch (extension) {
                    'pdf' => 'application/pdf',
                    'jpg' || 'jpeg' => 'image/jpeg',
                    'png' => 'image/png',
                    _ => 'application/octet-stream',
                  };
                  try {
                    await ref
                        .read(documentControllerProvider.notifier)
                        .uploadFile(
                          doc.id,
                          bytes: bytes,
                          fileName: file.name,
                          contentType: contentType,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (error) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Upload failed: $error')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Choose file and upload'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.doc, required this.tone, required this.onTap});

  final Document doc;
  final StatusTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doc.kind.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            StatusBadge(label: doc.status.label, tone: tone),
          ],
        ),
      ),
    );
  }
}
