import 'package:flutter/material.dart';

/// Central motion tokens. All decorative motion must respect reduced-motion.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration emphasized = Duration(milliseconds: 320);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.easeOutCubic;

  /// True when the platform requests minimal motion.
  static bool reduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Duration that collapses to zero under reduced motion.
  static Duration duration(BuildContext context, Duration preferred) {
    return reduceMotion(context) ? Duration.zero : preferred;
  }

  static Curve curve(BuildContext context) {
    return reduceMotion(context) ? Curves.linear : standardCurve;
  }
}
