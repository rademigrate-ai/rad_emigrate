import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/ai/ai_response.dart';
import '../../../../core/theme/premium_tokens.dart';

enum CitationCategory {
  radArticle,
  officialAuthority,
  generalWeb,
}

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
    final category = _determineCategory(source.url, source.authority);

    return InkWell(
      onTap: onTap ??
          () {
            if (source.url != null) {
              final uri = Uri.tryParse(source.url!);
              if (uri != null) launchUrl(uri);
            }
          },
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
                color: _badgeColor(category).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Text(
                '[$index]',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _badgeColor(category),
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
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
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
                      _buildCategoryChip(category),
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

  Color _badgeColor(CitationCategory cat) {
    switch (cat) {
      case CitationCategory.radArticle:
        return AppColors.primaryRed;
      case CitationCategory.officialAuthority:
        return AppColors.teal;
      case CitationCategory.generalWeb:
        return AppColors.navy;
    }
  }

  Widget _buildCategoryChip(CitationCategory cat) {
    IconData icon;
    String label;
    Color color;

    switch (cat) {
      case CitationCategory.radArticle:
        icon = Icons.article_outlined;
        label = 'مقاله تخصصی راد';
        color = AppColors.primaryRed;
        break;
      case CitationCategory.officialAuthority:
        icon = Icons.verified_outlined;
        label = 'منبع رسمی';
        color = AppColors.teal;
        break;
      case CitationCategory.generalWeb:
        icon = Icons.public;
        label = 'وب عمومی';
        color = AppColors.textSecondary;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  static CitationCategory _determineCategory(String? url, String? authority) {
    if (url != null) {
      final u = url.toLowerCase();
      if (u.contains('radvisa') ||
          u.contains('digivisa') ||
          u.contains('radmohajer')) {
        return CitationCategory.radArticle;
      }
      if (u.contains('.gov') ||
          u.contains('.gc.ca') ||
          u.contains('canada.ca') ||
          u.contains('.edu') ||
          u.contains('homeaffairs') ||
          u.contains('auswaertiges') ||
          u.contains('make-it-in-germany')) {
        return CitationCategory.officialAuthority;
      }
    }
    if (authority != null && authority.isNotEmpty) {
      return CitationCategory.officialAuthority;
    }
    // Default to officialAuthority when neither URL nor authority is given for compatibility
    if (url == null && authority == null) {
      return CitationCategory.officialAuthority;
    }
    return CitationCategory.generalWeb;
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

