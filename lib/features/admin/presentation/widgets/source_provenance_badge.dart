import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';

/// Trust and provenance levels for official and research sources.
enum SourceTrustLevel {
  officiallyVerified,
  adminDefined,
  aiSuggested,
  conflicting,
  unverified;

  static SourceTrustLevel fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'verified':
      case 'officially_verified':
        return SourceTrustLevel.officiallyVerified;
      case 'admin_defined':
      case 'custom':
      case 'admin':
        return SourceTrustLevel.adminDefined;
      case 'ai_suggested':
      case 'ai_discovered':
      case 'discovery':
        return SourceTrustLevel.aiSuggested;
      case 'conflicting':
      case 'conflict':
        return SourceTrustLevel.conflicting;
      case 'unverified':
      case 'provisional':
      default:
        return SourceTrustLevel.unverified;
    }
  }

  String toDisplayPersian() {
    switch (this) {
      case SourceTrustLevel.officiallyVerified:
        return 'تأییدشده رسمی';
      case SourceTrustLevel.adminDefined:
        return 'وارد شده توسط مدیر · فاقد تأییدیه رسمی';
      case SourceTrustLevel.aiSuggested:
        return 'پیشنهاد هوش مصنوعی · در انتظار راستی‌آزمایی';
      case SourceTrustLevel.conflicting:
        return 'دارای تناقض در مراجع';
      case SourceTrustLevel.unverified:
        return 'در انتظار راستی‌آزمایی';
    }
  }

  String toDisplayEnglish() {
    switch (this) {
      case SourceTrustLevel.officiallyVerified:
        return 'Officially Verified';
      case SourceTrustLevel.adminDefined:
        return 'Admin-Provided · Unverified';
      case SourceTrustLevel.aiSuggested:
        return 'AI-Suggested · Awaiting Verification';
      case SourceTrustLevel.conflicting:
        return 'Conflicting Sources Detected';
      case SourceTrustLevel.unverified:
        return 'Awaiting Verification';
    }
  }

  IconData get icon {
    switch (this) {
      case SourceTrustLevel.officiallyVerified:
        return Icons.verified;
      case SourceTrustLevel.adminDefined:
        return Icons.person_outline;
      case SourceTrustLevel.aiSuggested:
        return Icons.auto_awesome;
      case SourceTrustLevel.conflicting:
        return Icons.warning_amber_rounded;
      case SourceTrustLevel.unverified:
        return Icons.help_outline;
    }
  }

  Color get color {
    switch (this) {
      case SourceTrustLevel.officiallyVerified:
        return AppColors.teal;
      case SourceTrustLevel.adminDefined:
        return AppColors.navy;
      case SourceTrustLevel.aiSuggested:
        return const Color(0xFF7C3AED); // Accessible purple
      case SourceTrustLevel.conflicting:
        return AppColors.warning;
      case SourceTrustLevel.unverified:
        return AppColors.textSecondary;
    }
  }
}

/// Accessible badge displaying source provenance and trust level.
class SourceProvenanceBadge extends StatelessWidget {
  final SourceTrustLevel trustLevel;
  final bool isPersian;
  final bool showIcon;
  final double fontSize;

  const SourceProvenanceBadge({
    super.key,
    required this.trustLevel,
    this.isPersian = true,
    this.showIcon = true,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final color = trustLevel.color;
    final label = isPersian
        ? trustLevel.toDisplayPersian()
        : trustLevel.toDisplayEnglish();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(trustLevel.icon, size: fontSize + 3, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
