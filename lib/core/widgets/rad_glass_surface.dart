import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/premium_tokens.dart';

/// Selective glass for elevated panels; ordinary content does not require blur.
class RadGlassSurface extends StatelessWidget {
  const RadGlassSurface({
    super.key,
    required this.child,
    this.blur = false,
    this.radius = AppRadii.xl,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final bool blur;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premium;
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: AppMotion.reduceMotion(context) ? tokens.surface : tokens.glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tokens.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(padding: padding, child: child),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: blur && !AppMotion.reduceMotion(context)
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: content,
            )
          : content,
    );
  }
}
