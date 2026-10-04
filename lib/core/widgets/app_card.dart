import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: emphasized
            ? scheme.primary.withValues(alpha: 0.28)
            : theme.dividerColor,
      ),
    );
    final content = Padding(padding: padding, child: child);
    return Padding(
      padding: margin,
      child: Material(
        color: emphasized
            ? Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.06),
                scheme.surface,
              )
            : theme.cardColor,
        elevation: emphasized ? 1 : 0,
        shadowColor: scheme.shadow.withValues(alpha: 0.10),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : Semantics(
                button: true,
                child: InkWell(
                  onTap: onTap,
                  overlayColor: WidgetStatePropertyAll(
                    scheme.primary.withValues(alpha: 0.06),
                  ),
                  child: content,
                ),
              ),
      ),
    );
  }
}
