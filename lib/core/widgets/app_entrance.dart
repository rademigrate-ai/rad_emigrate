import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// One restrained entry transition; identity keys restart it on navigation.
class AppEntrance extends StatelessWidget {
  const AppEntrance({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.standard,
      curve: AppMotion.standardCurve,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}
