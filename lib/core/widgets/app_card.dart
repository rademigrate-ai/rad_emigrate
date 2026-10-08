import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Shared RAD surface with touch, mouse, keyboard, and reduced-motion support.
class AppCard extends StatefulWidget {
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
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _interactive => widget.onTap != null;

  void _setStateIfMounted(VoidCallback change) {
    if (mounted) setState(change);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = _interactive && (_hovered || _focused || _pressed);
    final elevated = _hovered || _focused;
    final borderColor = active
        ? scheme.secondary.withValues(alpha: 0.58)
        : widget.emphasized
        ? scheme.primary.withValues(alpha: 0.28)
        : theme.dividerColor;
    final surface = widget.emphasized
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.06),
            scheme.surface,
          )
        : theme.cardColor;
    final duration = AppMotion.duration(context, AppMotion.hover);
    final content = Padding(padding: widget.padding, child: widget.child);

    final card = AnimatedScale(
      duration: duration,
      curve: AppMotion.curve(context, preferred: AppMotion.emphasizedCurve),
      scale: _pressed
          ? 0.992
          : elevated
          ? 1.006
          : 1,
      child: AnimatedContainer(
        duration: duration,
        curve: AppMotion.curve(context, preferred: AppMotion.emphasizedCurve),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: scheme.secondary.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: _interactive
              ? InkWell(
                  onTap: widget.onTap,
                  onHover: (value) =>
                      _setStateIfMounted(() => _hovered = value),
                  onFocusChange: (value) =>
                      _setStateIfMounted(() => _focused = value),
                  onHighlightChanged: (value) =>
                      _setStateIfMounted(() => _pressed = value),
                  overlayColor: WidgetStatePropertyAll(
                    scheme.secondary.withValues(alpha: 0.08),
                  ),
                  child: content,
                )
              : content,
        ),
      ),
    );

    return Padding(
      padding: widget.margin,
      child: _interactive
          ? Semantics(button: true, child: card)
          : ExcludeSemantics(excluding: false, child: card),
    );
  }
}
