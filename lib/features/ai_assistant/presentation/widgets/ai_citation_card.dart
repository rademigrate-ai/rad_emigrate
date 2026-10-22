import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/ai/ai_response.dart';
import '../../../../core/theme/premium_tokens.dart';

class AiCitationCard extends StatelessWidget {
  final int index;
  final AiSource source;
  final VoidCallback? onTap;

  const AiCitationCard({
    super.key,
    required this.index,
    required this.source,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final domain = _extractDomain(source.url);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.premium.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: context.premium.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Text(
                '[$index]',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryRed,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.premium.text,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (source.authority != null) ...[
                        Text(
                          source.authority!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.teal,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (domain != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navyMuted.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            domain,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.navyMuted,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.verified_outlined,
                            size: 12,
                            color: AppColors.success,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'منبع رسمی',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _extractDomain(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(rawUrl);
      return uri.host.isNotEmpty ? uri.host : null;
    } catch (_) {
      return null;
    }
  }
}
