import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/errors/localized_error_message.dart';
import '../../../../core/widgets/premium_visuals.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../../../core/widgets/reference_widgets.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/document.dart';
import '../../domain/entities/document_type.dart';
import '../providers/document_controller.dart';

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});
  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  DocumentTypeKind? _filter;

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(documentControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/profile'),
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
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
        ),
      ),
      body: PremiumCanvas(
        child: state.when(
          loading: () => LoadingState.section(message: l10n.loadingDocuments),
          error: (e, _) => ErrorState(
            message: localizedDataError(e, l10n),
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

            final filtered = docs
                .where((doc) => _filter == null || doc.kind == _filter)
                .toList();
            final kinds = docs.map((doc) => doc.kind).toSet();
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: ChoiceChip(
                              label: Text(l10n.allItems),
                              selected: _filter == null,
                              selectedColor: context.premium.accent,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                color: _filter == null
                                    ? Colors.white
                                    : context.premium.mutedText,
                              ),
                              onSelected: (_) => setState(() => _filter = null),
                            ),
                          ),
                          for (final kind in kinds)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 6),
                              child: ChoiceChip(
                                label: Text(_kindLabel(kind, l10n)),
                                selected: _filter == kind,
                                selectedColor: context.premium.accent,
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  color: _filter == kind
                                      ? Colors.white
                                      : context.premium.mutedText,
                                ),
                                onSelected: (_) =>
                                    setState(() => _filter = kind),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final doc in filtered)
                      _DocTile(
                        doc: doc,
                        tone: _tone(doc.status),
                        kindLabel: _kindLabel(doc.kind, l10n),
                        statusLabel: _statusLabel(doc.status, l10n),
                        onTap: () => _openSheet(context, ref, doc),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
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
                  Container(
                    height: 150,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.premium.surfaceElevated,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      size: 64,
                      color: context.premium.information,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  if (doc.storagePath != null &&
                      doc.status != DocumentVerificationStatus.missing) ...[
                    OutlinedButton.icon(
                      onPressed: isUploading
                          ? null
                          : () async {
                              try {
                                uploading.value = true;
                                final preview = await ref
                                    .read(documentControllerProvider.notifier)
                                    .previewDocument(doc.id);
                                final opened = await launchUrl(
                                  preview,
                                  mode: LaunchMode.externalApplication,
                                );
                                if (!opened) {
                                  throw StateError('Preview unavailable');
                                }
                              } catch (_) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(sheetL10n.errorGeneric),
                                    ),
                                  );
                                }
                              } finally {
                                if (ctx.mounted) {
                                  uploading.value = false;
                                }
                              }
                            },
                      icon: const Icon(Icons.visibility_outlined),
                      label: Text(sheetL10n.viewDocumentFile),
                    ),
                    const SizedBox(height: 8),
                  ],
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
    final color = switch (doc.kind) {
      DocumentTypeKind.passport => const Color(0xFFE59B13),
      DocumentTypeKind.education => const Color(0xFF345CFF),
      DocumentTypeKind.financial => const Color(0xFF00A986),
      DocumentTypeKind.identity => const Color(0xFFD91F2B),
      _ => const Color(0xFF4385DA),
    };
    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          ReferenceIcon(
            icon: doc.kind == DocumentTypeKind.education
                ? Icons.school_outlined
                : Icons.description_outlined,
            color: color,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    kindLabel,
                    if (doc.mimeType != null)
                      doc.mimeType!.split('/').last.toUpperCase(),
                  ].join(' / '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: context.premium.mutedText),
                ),
              ],
            ),
          ),
          if (doc.updatedAt != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Text(
                MaterialLocalizations.of(context)
                    .formatShortDate(doc.updatedAt!),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }
}
