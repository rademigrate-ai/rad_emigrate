import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum StatusTone { neutral, info, warning, success, danger }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
  });

  final String label;
  final StatusTone tone;

  Color get _bg {
    switch (tone) {
      case StatusTone.neutral:
        return AppColors.surfaceMuted;
      case StatusTone.info:
        return AppColors.info.withValues(alpha: 0.12);
      case StatusTone.warning:
        return AppColors.warning.withValues(alpha: 0.15);
      case StatusTone.success:
        return AppColors.success.withValues(alpha: 0.12);
      case StatusTone.danger:
        return AppColors.error.withValues(alpha: 0.12);
    }
  }

  Color get _fg {
    switch (tone) {
      case StatusTone.neutral:
        return AppColors.textSecondary;
      case StatusTone.info:
        return AppColors.info;
      case StatusTone.warning:
        return AppColors.warning;
      case StatusTone.success:
        return AppColors.success;
      case StatusTone.danger:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}
