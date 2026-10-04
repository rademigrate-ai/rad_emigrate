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
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool expanded;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: loading
          ? const SizedBox(
              key: ValueKey('loading'),
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label),
              ],
            ),
    );

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          disabledBackgroundColor: AppColors.primaryRed.withValues(alpha: 0.45),
          foregroundColor: AppColors.white,
        ),
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: loading ? null : onPressed,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: scheme.secondary),
          child: IconTheme(
            data: IconThemeData(color: scheme.secondary, size: 18),
            child: child,
          ),
        ),
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: loading ? null : onPressed,
        child: child,
      ),
    };

    final result = expanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
    return tooltip == null ? result : Tooltip(message: tooltip!, child: result);
  }
}
