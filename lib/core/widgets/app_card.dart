import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.emphasized = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: emphasized ? AppColors.primaryRed.withValues(alpha: 0.22) : AppColors.borderSubtle,
      ),
    );
    final content = Padding(padding: padding, child: child);
    return Padding(
      padding: margin,
      child: Material(
        color: emphasized ? AppColors.surfaceWarm : AppColors.surface,
        elevation: emphasized ? 1 : 0,
        shadowColor: AppColors.navy.withValues(alpha: 0.10),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : Semantics(
                button: true,
                child: InkWell(
                  onTap: onTap,
                  overlayColor: WidgetStatePropertyAll(
                    AppColors.navy.withValues(alpha: 0.05),
                  ),
                  child: content,
                ),
              ),
      ),
    );
  }
}
