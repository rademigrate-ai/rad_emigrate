import 'package:flutter/material.dart';
import 'package:rad_emigrate/core/widgets/rad_flapping_bird.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';

enum DocumentProcessingStatus {
  selected,
  uploading,
  processing,
  analyzed,
  failed,
}

class AiDocumentAttachment {
  const AiDocumentAttachment({
    required this.name,
    required this.sizeBytes,
    required this.extension,
    this.path,
    this.bytes,
    this.status = DocumentProcessingStatus.selected,
    this.extractedFacts = const {},
    this.errorMessage,
  });

  final String name;
  final int sizeBytes;
  final String extension;
  final String? path;
  final List<int>? bytes;
  final DocumentProcessingStatus status;
  final Map<String, String> extractedFacts;
  final String? errorMessage;

  bool get isPdf => extension.toLowerCase() == 'pdf';

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  AiDocumentAttachment copyWith({
    DocumentProcessingStatus? status,
    Map<String, String>? extractedFacts,
    String? errorMessage,
  }) {
    return AiDocumentAttachment(
      name: name,
      sizeBytes: sizeBytes,
      extension: extension,
      path: path,
      bytes: bytes,
      status: status ?? this.status,
      extractedFacts: extractedFacts ?? this.extractedFacts,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AiDocumentChip extends StatelessWidget {
  const AiDocumentChip({super.key, required this.attachment, this.onRemove});

  final AiDocumentAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    Widget statusIndicator;

    switch (attachment.status) {
      case DocumentProcessingStatus.selected:
        statusColor = AppColors.navy;
        statusLabel = attachment.formattedSize;
        statusIndicator = const SizedBox.shrink();
        break;
      case DocumentProcessingStatus.uploading:
        statusColor = AppColors.navy;
        statusLabel = 'در حال بارگذاری...';
        statusIndicator = const Padding(
          padding: EdgeInsetsDirectional.only(end: 4),
          child: SizedBox(
            width: 10,
            height: 10,
            child: RadFlappingBird(size: 10, showAura: false),
          ),
        );
        break;
      case DocumentProcessingStatus.processing:
        statusColor = AppColors.warning;
        statusLabel = 'در حال استخراج اطلاعات...';
        statusIndicator = const Padding(
          padding: EdgeInsetsDirectional.only(end: 4),
          child: SizedBox(
            width: 10,
            height: 10,
            child: RadFlappingBird(size: 10, showAura: false),
          ),
        );
        break;
      case DocumentProcessingStatus.analyzed:
        statusColor = AppColors.teal;
        statusLabel = 'بررسی شد';
        statusIndicator = const Padding(
          padding: EdgeInsetsDirectional.only(end: 4),
          child: Icon(Icons.check_circle, size: 12, color: AppColors.teal),
        );
        break;
      case DocumentProcessingStatus.failed:
        statusColor = AppColors.error;
        statusLabel = attachment.errorMessage ?? 'خطای پردازش';
        statusIndicator = const Padding(
          padding: EdgeInsetsDirectional.only(end: 4),
          child: Icon(Icons.error_outline, size: 12, color: AppColors.error),
        );
        break;
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.premium.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: context.premium.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            attachment.isPdf ? Icons.picture_as_pdf : Icons.image,
            size: 20,
            color: attachment.isPdf ? AppColors.primaryRed : AppColors.teal,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    statusIndicator,
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onRemove != null &&
              attachment.status != DocumentProcessingStatus.uploading &&
              attachment.status != DocumentProcessingStatus.processing) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
