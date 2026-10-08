import 'package:flutter/material.dart';

import 'motion_primitives.dart';

/// Default route entry transition. Identity keys restart it on navigation.
class AppEntrance extends StatelessWidget {
  const AppEntrance({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MotionReveal(
      restartKey: key,
      offset: const Offset(0, 0.025),
      child: child,
    );
  }
}
