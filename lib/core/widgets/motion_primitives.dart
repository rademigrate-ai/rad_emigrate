import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// A one-time reveal for pages, sections, and content rows.
///
/// It is intentionally controller-backed so a delay can be cancelled safely
/// when a route leaves the tree. Reduced motion renders the child immediately.
class MotionReveal extends StatefulWidget {
  const MotionReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.cardEntrance,
    this.offset = const Offset(0, 0.035),
    this.scaleBegin = 0.985,
    this.restartKey,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final double scaleBegin;
  final Object? restartKey;

  @override
  State<MotionReveal> createState() => _MotionRevealState();
}

class _MotionRevealState extends State<MotionReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _delayTimer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _restart();
    } else if (AppMotion.reduceMotion(context)) {
      _delayTimer?.cancel();
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant MotionReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restartKey != widget.restartKey ||
        oldWidget.delay != widget.delay ||
        oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      _restart();
    }
  }

  void _restart() {
    _delayTimer?.cancel();
    if (AppMotion.reduceMotion(context)) {
      _controller.value = 1;
      return;
    }
    _controller.value = 0;
    if (widget.delay == Duration.zero) {
      _controller.forward();
      return;
    }
    _delayTimer = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) return widget.child;
    final animation = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.enterCurve,
    );
    return AnimatedBuilder(
      animation: animation,
      child: widget.child,
      builder: (context, child) {
        final value = animation.value;
        return Opacity(
          opacity: value,
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: widget.offset * (1 - value),
            child: Transform.scale(
              scale: widget.scaleBegin + ((1 - widget.scaleBegin) * value),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Applies a consistent reveal delay to repeated content without delaying data.
class MotionStagger extends StatelessWidget {
  const MotionStagger({
    super.key,
    required this.index,
    required this.child,
    this.offset = const Offset(0, 0.035),
  });

  final int index;
  final Widget child;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return MotionReveal(
      delay: AppMotion.staggerDelay(index),
      offset: offset,
      restartKey: index,
      child: child,
    );
  }
}

/// A low-cost ambient backdrop for focused, non-operational product moments.
///
/// The animation runs only while [active] is true and stops entirely for
/// reduced-motion users. It uses a single repaint boundary and no shader.
class AmbientBackdrop extends StatefulWidget {
  const AmbientBackdrop({
    super.key,
    required this.child,
    this.active = true,
    this.primary = const Color(0xFF25B7B3),
    this.secondary = const Color(0xFF5278D7),
  });

  final Widget child;
  final bool active;
  final Color primary;
  final Color secondary;

  @override
  State<AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _AmbientBackdropState extends State<AmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.ambient);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant AmbientBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.active && !AppMotion.reduceMotion(context)) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staticValue = AppMotion.reduceMotion(context) || !widget.active;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: IgnorePointer(
            child: staticValue
                ? _BackdropLayer(
                    primary: widget.primary,
                    secondary: widget.secondary,
                    value: 0,
                  )
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _BackdropLayer(
                      primary: widget.primary,
                      secondary: widget.secondary,
                      value: _controller.value,
                    ),
                  ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _BackdropLayer extends StatelessWidget {
  const _BackdropLayer({
    required this.primary,
    required this.secondary,
    required this.value,
  });

  final Color primary;
  final Color secondary;
  final double value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.72 + (value * 0.3), -0.78 + (value * 0.18)),
          radius: 1.12,
          colors: [primary.withValues(alpha: 0.15), Colors.transparent],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.78 - (value * 0.24), 0.72 - (value * 0.14)),
            radius: 1.02,
            colors: [secondary.withValues(alpha: 0.1), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

/// Animates a verified integer value without inventing a replacement value.
class MotionCount extends StatelessWidget {
  const MotionCount({
    super.key,
    required this.value,
    required this.placeholder,
    this.style,
  });

  final int? value;
  final String placeholder;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (value == null) return Text(placeholder, style: style);
    if (AppMotion.reduceMotion(context)) return Text('$value', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value!.toDouble()),
      duration: AppMotion.duration(context, AppMotion.progress),
      curve: AppMotion.enterCurve,
      builder: (context, current, _) =>
          Text('${current.round()}', style: style),
    );
  }
}

/// Static skeleton surface for real loading states. Static rendering avoids an
/// always-running shimmer while retaining a predictable layout and semantics.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, this.height = 16, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}
