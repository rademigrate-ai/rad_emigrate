import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_motion.dart';

enum AppButtonVariant { primary, secondary, ghost }

class AppButton extends StatefulWidget {
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
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = !widget.loading && widget.onPressed != null;
    final duration = AppMotion.duration(context, AppMotion.buttonFeedback);
    final child = AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppMotion.curve(context),
      switchOutCurve: AppMotion.exitCurve,
      child: widget.loading
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
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(widget.label),
              ],
            ),
    );

    final button = switch (widget.variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: widget.loading ? null : widget.onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          disabledBackgroundColor: AppColors.primaryRed.withValues(alpha: 0.45),
          foregroundColor: AppColors.white,
          animationDuration: duration,
        ),
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: widget.loading ? null : widget.onPressed,
        style: OutlinedButton.styleFrom(animationDuration: duration),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: scheme.secondary),
          child: IconTheme(
            data: IconThemeData(color: scheme.secondary, size: 18),
            child: child,
          ),
        ),
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: widget.loading ? null : widget.onPressed,
        style: TextButton.styleFrom(animationDuration: duration),
        child: child,
      ),
    };

    final result = widget.expanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
    final interactive = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled ? (_) => setState(() => _hovered = false) : null,
      child: AnimatedScale(
        duration: duration,
        curve: AppMotion.curve(context, preferred: AppMotion.emphasizedCurve),
        scale: _hovered ? 1.015 : 1,
        child: result,
      ),
    );
    return widget.tooltip == null
        ? interactive
        : Tooltip(message: widget.tooltip!, child: interactive);
  }
}
