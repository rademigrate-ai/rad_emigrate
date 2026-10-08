import 'package:flutter/material.dart';

/// Central motion tokens for RAD.
///
/// Product motion is deliberately short, purposeful, and fully disabled when
/// the operating system requests reduced motion. Widgets must use these tokens
/// rather than introducing ad-hoc durations or curves.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration buttonFeedback = Duration(milliseconds: 140);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration hover = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 260);
  static const Duration modal = Duration(milliseconds: 240);
  static const Duration cardEntrance = Duration(milliseconds: 320);
  static const Duration emphasized = Duration(milliseconds: 380);
  static const Duration page = Duration(milliseconds: 380);
  static const Duration progress = Duration(milliseconds: 420);
  static const Duration stagger = Duration(milliseconds: 60);
  static const Duration ambient = Duration(seconds: 14);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Cubic(0.16, 1, 0.3, 1);
  static const Curve enterCurve = Cubic(0.22, 1, 0.36, 1);
  static const Curve exitCurve = Curves.easeInCubic;

  /// True when the operating system requests minimal motion.
  static bool reduceMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  /// Duration that collapses to zero under reduced-motion.
  static Duration duration(BuildContext context, Duration preferred) {
    return reduceMotion(context) ? Duration.zero : preferred;
  }

  /// Curve with no perceptible easing when motion is disabled.
  static Curve curve(BuildContext context, {Curve preferred = standardCurve}) {
    return reduceMotion(context) ? Curves.linear : preferred;
  }

  /// Converts a logical horizontal entrance into the correct physical direction.
  /// A positive value originates from the reading-direction start edge.
  static Offset fromDirectionalStart(BuildContext context, double distance) {
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    return Offset(direction == TextDirection.rtl ? distance : -distance, 0);
  }

  static Duration staggerDelay(int index) {
    // Long lists should not delay late items by several seconds.
    final boundedIndex = index < 0
        ? 0
        : index > 7
        ? 7
        : index;
    return Duration(milliseconds: stagger.inMilliseconds * boundedIndex);
  }
}
