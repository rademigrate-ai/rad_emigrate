import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../domain/entities/canonical_pathway_entities.dart';

class ArticleChangeHighlightsBanner extends StatefulWidget {
  final DateTime? lastFactCheckedAt;
  final List<OfficialSourceAttribution> officialSources;
  final List<PathwaySection> sections;

  const ArticleChangeHighlightsBanner({
    super.key,
    required this.lastFactCheckedAt,
    required this.officialSources,
    required this.sections,
  });

  @override
  State<ArticleChangeHighlightsBanner> createState() =>
      _ArticleChangeHighlightsBannerState();
}

class _ArticleChangeHighlightsBannerState
    extends State<ArticleChangeHighlightsBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.officialSources.isEmpty && widget.lastFactCheckedAt == null) {
      return const SizedBox.shrink();
    }

    final primarySource = widget.officialSources.isNotEmpty
        ? widget.officialSources.first
        : null;

    final dateStr = widget.lastFactCheckedAt != null
        ? '${widget.lastFactCheckedAt!.year}/${widget.lastFactCheckedAt!.month.toString().padLeft(2, '0')}/${widget.lastFactCheckedAt!.day.toString().padLeft(2, '0')}'
        : 'ثبت نشده';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Bar
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history_edu_outlined,
                      size: 18,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'منابع و وضعیت بررسی',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        Text(
                          'تاریخ بررسی ثبت‌شده: $dateStr • ${primarySource != null ? primarySource.authorityName : 'منبع ارائه نشده'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Details
          if (_expanded) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'منابع ثبت‌شده برای این نسخه:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.officialSources.isNotEmpty)
                    ...widget.officialSources.map((source) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_balance,
                                  size: 14,
                                  color: AppColors.teal,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  source.authorityName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ],
                            ),
                            if (source.authorityDomain.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'دامنه منبع: ${source.authorityDomain}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (source.originalEvidenceUrl.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'لینک سند: ${source.originalEvidenceUrl}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primaryRed,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    })
                  else
                    const Text(
                      'برای این نسخه منبعی ارائه نشده است؛ انطباق قانونی احراز نشده است.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'وجود منبع یا تاریخ به‌تنهایی به معنی تأیید قانونی یا تصویب انسانی نیست. انتشار به تأیید صریح سردبیر نیاز دارد.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.navy,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
