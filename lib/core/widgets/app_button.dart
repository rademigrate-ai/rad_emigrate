import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum AppButtonVariant { primary, secondary, ghost }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            disabledBackgroundColor: AppColors.primaryRed.withValues(alpha: 0.5),
          ),
          child: child,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: loading ? null : onPressed,
          child: child is Row
              ? DefaultTextStyle.merge(
                  style: const TextStyle(color: AppColors.navy),
                  child: IconTheme(
                    data: const IconThemeData(color: AppColors.navy, size: 18),
                    child: child,
                  ),
                )
              : child,
        ),
      AppButtonVariant.ghost => TextButton(
          onPressed: loading ? null : onPressed,
          child: child,
        ),
    };

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
