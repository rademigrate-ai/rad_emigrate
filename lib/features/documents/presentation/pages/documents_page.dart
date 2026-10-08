import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../l10n/app_localizations.dart';
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

  String _kindLabel(DocumentTypeKind kind, AppLocalizations l10n) {
    return switch (kind) {
      DocumentTypeKind.passport => l10n.documentTypePassport,
      DocumentTypeKind.identity => l10n.documentTypeIdentity,
      DocumentTypeKind.education => l10n.documentTypeEducation,
      DocumentTypeKind.financial => l10n.documentTypeFinancial,
      DocumentTypeKind.visa => l10n.documentTypeVisa,
      DocumentTypeKind.other => l10n.documentTypeOther,
    };
  }

  String _statusLabel(
    DocumentVerificationStatus status,
    AppLocalizations l10n,
  ) {
    return switch (status) {
      DocumentVerificationStatus.missing => l10n.documentStatusMissing,
      DocumentVerificationStatus.uploaded => l10n.documentStatusUploaded,
      DocumentVerificationStatus.underReview => l10n.documentStatusUnderReview,
      DocumentVerificationStatus.verified => l10n.documentStatusVerified,
      DocumentVerificationStatus.rejected => l10n.documentStatusRejected,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(documentControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.documents),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
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
        label: Text(l10n.addType),
        onPressed: () async {
          await ref
              .read(documentControllerProvider.notifier)
              .addDocumentType(
                name: l10n.newDocument,
                kind: DocumentTypeKind.other,
              );
        },
      ),
      body: state.when(
        loading: () => LoadingState.section(message: l10n.loadingDocuments),
        error: (e, _) => ErrorState(
          message: l10n.errorGeneric,
          onRetry: () => ref.read(documentControllerProvider.notifier).load(),
        ),
        data: (docs) {
          if (docs.isEmpty) {
            return EmptyState(
              title: l10n.noDocuments,
              subtitle: l10n.noDocumentsSubtitle,
              icon: Icons.folder_outlined,
            );
          }

          final missing = docs
              .where((d) => d.status == DocumentVerificationStatus.missing)
              .toList();
          final rest = docs
              .where((d) => d.status != DocumentVerificationStatus.missing)
              .toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
                children: [
                  if (missing.isNotEmpty) ...[
                    SectionHeader(
                      title: l10n.missingSection,
                      subtitle: l10n.missingSectionSubtitle,
                    ),
                    ...missing.asMap().entries.map(
                      (entry) => MotionStagger(
                        index: entry.key,
                        child: _DocTile(
                          doc: entry.value,
                          tone: _tone(entry.value.status),
                          kindLabel: _kindLabel(entry.value.kind, l10n),
                          statusLabel: _statusLabel(entry.value.status, l10n),
                          onTap: () => _openSheet(context, ref, entry.value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SectionHeader(
                    title: missing.isEmpty
                        ? l10n.allDocuments
                        : l10n.submittedSection,
                  ),
                  ...rest.asMap().entries.map(
                    (entry) => MotionStagger(
                      index: entry.key + missing.length,
                      child: _DocTile(
                        doc: entry.value,
                        tone: _tone(entry.value.status),
                        kindLabel: _kindLabel(entry.value.kind, l10n),
                        statusLabel: _statusLabel(entry.value.status, l10n),
                        onTap: () => _openSheet(context, ref, entry.value),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openSheet(BuildContext context, WidgetRef ref, Document doc) {
    final uploading = ValueNotifier(false);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final sheetL10n = AppLocalizations.of(ctx);
        return ValueListenableBuilder<bool>(
          valueListenable: uploading,
          builder: (ctx, isUploading, _) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(doc.name, style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '${sheetL10n.typeLabel}: '
                    '${_kindLabel(doc.kind, sheetL10n)}',
                  ),
                  Text(
                    '${sheetL10n.statusLabel}: '
                    '${_statusLabel(doc.status, sheetL10n)}',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    sheetL10n.acceptedFormats,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  if (isUploading) ...[
                    const SizedBox(height: 16),
                    RadInlineLoading(label: sheetL10n.loading),
                  ],
                  const SizedBox(height: 20),
                  if (doc.status == DocumentVerificationStatus.missing ||
                      doc.status == DocumentVerificationStatus.rejected)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: isUploading
                          ? null
                          : () async {
                              final result = await FilePicker.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: const [
                                  'pdf',
                                  'jpg',
                                  'jpeg',
                                  'png',
                                ],
                                withData: true,
                              );
                              if (result == null || result.files.isEmpty) {
                                return;
                              }
                              final file = result.files.single;
                              final bytes = file.bytes;
                              if (bytes == null) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(sheetL10n.couldNotReadFile),
                                    ),
                                  );
                                }
                                return;
                              }
                              if (bytes.length > 10 * 1024 * 1024) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(sheetL10n.fileTooLarge),
                                    ),
                                  );
                                }
                                return;
                              }
                              final extension = (file.extension ?? '')
                                  .toLowerCase();
                              final contentType = switch (extension) {
                                'pdf' => 'application/pdf',
                                'jpg' || 'jpeg' => 'image/jpeg',
                                'png' => 'image/png',
                                _ => 'application/octet-stream',
                              };
                              try {
                                uploading.value = true;
                                await ref
                                    .read(documentControllerProvider.notifier)
                                    .uploadFile(
                                      doc.id,
                                      bytes: bytes,
                                      fileName: file.name,
                                      contentType: contentType,
                                    );
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (_) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(sheetL10n.uploadFailed),
                                    ),
                                  );
                                }
                              } finally {
                                if (ctx.mounted) {
                                  uploading.value = false;
                                }
                              }
                            },
                      icon: const Icon(Icons.upload_file),
                      label: Text(sheetL10n.chooseFileUpload),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: ctx,
                        builder: (dialogContext) => AlertDialog(
                          title: Text(sheetL10n.deleteDocumentTitle),
                          content: Text(sheetL10n.deleteDocumentBody),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: Text(sheetL10n.cancel),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: Text(sheetL10n.delete),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      try {
                        await ref
                            .read(documentControllerProvider.notifier)
                            .deleteDocument(doc.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (_) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(sheetL10n.deleteFailed)),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(sheetL10n.deleteDocument),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(sheetL10n.close),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(uploading.dispose);
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.doc,
    required this.tone,
    required this.kindLabel,
    required this.statusLabel,
    required this.onTap,
  });

  final Document doc;
  final StatusTone tone;
  final String kindLabel;
  final String statusLabel;
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(kindLabel, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(label: statusLabel, tone: tone),
          ],
        ),
      ),
    );
  }
}
