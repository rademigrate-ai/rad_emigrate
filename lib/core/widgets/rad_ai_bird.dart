import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_motion.dart';

enum RadAiBirdState { idle, listening, thinking, responding, newMessage }

/// Stateful RAD assistant identity built from the approved phoenix artwork.
///
/// Each product state has a distinct motion signature and static silhouette.
/// Reduced Motion freezes the animation while retaining the visual state cue.
class RadAiBird extends StatefulWidget {
  const RadAiBird({
    super.key,
    required this.state,
    required this.semanticLabel,
    this.size = 176,
  });

  final RadAiBirdState state;
  final String semanticLabel;
  final double size;

  @override
  State<RadAiBird> createState() => _RadAiBirdState();
}

class _RadAiBirdState extends State<RadAiBird>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration get _duration => switch (widget.state) {
    RadAiBirdState.idle => const Duration(milliseconds: 2600),
    RadAiBirdState.listening => const Duration(milliseconds: 1200),
    RadAiBirdState.thinking => const Duration(milliseconds: 1900),
    RadAiBirdState.responding => const Duration(milliseconds: 820),
    RadAiBirdState.newMessage => const Duration(milliseconds: 1050),
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant RadAiBird oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _controller.duration = _duration;
      _controller.value = 0;
      _syncMotion();
    }
  }

  void _syncMotion() {
    if (AppMotion.reduceMotion(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _controller.stop();
      _controller.value = .35;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      liveRegion: widget.state == RadAiBirdState.newMessage,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: widget.size,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value * math.pi * 2;
                final reduced = AppMotion.reduceMotion(context);
                final pose = reduced ? 0.0 : math.sin(t);
                final dy = switch (widget.state) {
                  RadAiBirdState.idle => pose * 2.5,
                  RadAiBirdState.listening => pose.abs() * -1.4,
                  RadAiBirdState.thinking => math.sin(t * .5) * 2,
                  RadAiBirdState.responding => pose * 1.2,
                  RadAiBirdState.newMessage => pose.abs() * -4,
                };
                final wingAngle = switch (widget.state) {
                  RadAiBirdState.idle => pose * .025,
                  RadAiBirdState.listening => pose * .045,
                  RadAiBirdState.thinking => pose * .03,
                  RadAiBirdState.responding => pose * .085,
                  RadAiBirdState.newMessage => pose * .12,
                };
                return CustomPaint(
                  painter: _BirdStatePainter(
                    state: widget.state,
                    progress: _controller.value,
                  ),
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: reduced
                        ? child
                        : _ArticulatedBird(
                            key: const ValueKey('articulated-rad-bird'),
                            wingAngle: wingAngle,
                          ),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.all(widget.size * .12),
                child: Image.asset(
                  'assets/branding/rad_phoenix_final_512.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Splits the approved master into independently hinged wings and a stable
/// body. Every layer uses the same source pixels, so articulation never
/// redraws, recolors, or substitutes the RAD mark.
class _ArticulatedBird extends StatelessWidget {
  const _ArticulatedBird({super.key, required this.wingAngle});

  final double wingAngle;

  static const _asset = 'assets/branding/rad_phoenix_final_512.png';

  Widget _image() => Image.asset(
    _asset,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    excludeFromSemantics: true,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.rotate(
            key: const ValueKey('rad-bird-left-wing'),
            angle: -wingAngle,
            alignment: const Alignment(-.18, -.08),
            child: ClipPath(
              clipper: const _BirdLayerClipper(_BirdLayer.leftWing),
              clipBehavior: Clip.hardEdge,
              child: _image(),
            ),
          ),
          Transform.rotate(
            key: const ValueKey('rad-bird-right-wing'),
            angle: wingAngle,
            alignment: const Alignment(.18, -.08),
            child: ClipPath(
              clipper: const _BirdLayerClipper(_BirdLayer.rightWing),
              clipBehavior: Clip.hardEdge,
              child: _image(),
            ),
          ),
          ClipPath(
            key: const ValueKey('rad-bird-body'),
            clipper: const _BirdLayerClipper(_BirdLayer.body),
            clipBehavior: Clip.hardEdge,
            child: _image(),
          ),
        ],
      ),
    );
  }
}

enum _BirdLayer { leftWing, rightWing, body }

class _BirdLayerClipper extends CustomClipper<Path> {
  const _BirdLayerClipper(this.layer);

  final _BirdLayer layer;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return switch (layer) {
      _BirdLayer.leftWing =>
        Path()
          ..moveTo(0, 0)
          ..lineTo(w * .53, 0)
          ..lineTo(w * .53, h * .63)
          ..lineTo(w * .35, h)
          ..lineTo(0, h)
          ..close(),
      _BirdLayer.rightWing =>
        Path()
          ..moveTo(w * .47, 0)
          ..lineTo(w, 0)
          ..lineTo(w, h)
          ..lineTo(w * .65, h)
          ..lineTo(w * .47, h * .63)
          ..close(),
      _BirdLayer.body =>
        Path()
          ..moveTo(w * .34, h * .18)
          ..lineTo(w * .66, h * .18)
          ..lineTo(w * .66, h)
          ..lineTo(w * .34, h)
          ..close(),
    };
  }

  @override
  bool shouldReclip(covariant _BirdLayerClipper oldClipper) =>
      oldClipper.layer != layer;
}

class _BirdStatePainter extends CustomPainter {
  const _BirdStatePainter({required this.state, required this.progress});

  final RadAiBirdState state;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final red = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.2, size.width * .009)
      ..color = AppColors.primaryRed.withValues(alpha: .52);

    if (state == RadAiBirdState.listening) {
      for (var i = 0; i < 2; i++) {
        final radius = size.width * (.27 + i * .075 + progress * .025);
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(size.width * .73, size.height * .48),
            radius: radius,
          ),
          -math.pi * .38,
          math.pi * .76,
          false,
          red..color = red.color.withValues(alpha: .48 - i * .16),
        );
      }
    } else if (state == RadAiBirdState.thinking) {
      red.color = AppColors.primaryRed.withValues(alpha: .45);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: size.width * .42),
        progress * math.pi * 2,
        math.pi * 1.35,
        false,
        red,
      );
      final angle = progress * math.pi * 2;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * size.width * .42,
        size.width * .025,
        Paint()..color = const Color(0xFFFF6575),
      );
    } else if (state == RadAiBirdState.responding) {
      final alpha = .12 + ((math.sin(progress * math.pi * 2) + 1) * .1);
      canvas.drawCircle(
        center,
        size.width * .42,
        Paint()
          ..color = AppColors.primaryRed.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * .08),
      );
    } else if (state == RadAiBirdState.newMessage) {
      final badge = Offset(size.width * .78, size.height * .2);
      canvas.drawCircle(
        badge,
        size.width * .075,
        Paint()..color = AppColors.primaryRed,
      );
      canvas.drawCircle(
        badge,
        size.width * .025,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BirdStatePainter oldDelegate) =>
      oldDelegate.state != state || oldDelegate.progress != progress;
}
