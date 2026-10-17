import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_motion.dart';

/// The six continuous stages of a natural wing-flapping cycle.
///
/// 1. Wings Up: Highest elevation, upward stroke completion.
/// 2. Start Down: Air resistance engages, wings sweep forward and down.
/// 3. Mid Flap: Maximum downward propulsion and lift acceleration.
/// 4. Wings Down: Deep downstroke apex, body at peak elevation.
/// 5. Return Up: Wings fold slightly at inner joints to minimize drag.
/// 6. Continue Cycle: Wings smoothly reopen, returning to stage 1.
enum FlappingStage {
  wingsUp,
  startDown,
  midFlap,
  wingsDown,
  returnUp,
  continueCycle,
}

/// A lifecycle-safe, articulated wing-flapping RAD bird widget.
///
/// Implements the approved natural 6-stage flapping cycle from Reference 3.
/// Adapts gracefully across full-screen, section, card, button, and inline sizes.
class RadFlappingBird extends StatefulWidget {
  const RadFlappingBird({
    super.key,
    this.size = 48,
    this.color,
    this.active = true,
    this.showAura = false,
    this.semanticLabel,
  });

  /// Button loading variant with high-contrast monochrome rendering.
  const RadFlappingBird.button({
    super.key,
    this.size = 20,
    this.color = Colors.white,
    this.active = true,
    this.semanticLabel,
  }) : showAura = false;

  final double size;
  final Color? color;
  final bool active;
  final bool showAura;
  final String? semanticLabel;

  @override
  State<RadFlappingBird> createState() => _RadFlappingBirdState();
}

class _RadFlappingBirdState extends State<RadFlappingBird>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _flapDuration = Duration(milliseconds: 880);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _flapDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(
      const AssetImage('assets/branding/rad_flying_bird_128.png'),
      context,
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant RadFlappingBird oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (!mounted) return;
    if (widget.active &&
        !AppMotion.reduceMotion(context) &&
        TickerMode.valuesOf(context).enabled) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.value = 0.35; // Settled graceful gliding pose
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduceMotion(context);
    final size = widget.size;

    Widget content = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = reduced ? 0.35 : _controller.value;
        final angles = _computeKinetics(progress);

        return CustomPaint(
          painter: widget.showAura
              ? _BirdAuraPainter(progress: progress, color: widget.color)
              : null,
          child: SizedBox.square(
            dimension: size,
            child: Transform.translate(
              offset: Offset(0, angles.bodyDy * size),
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  // Secondary wing (background)
                  Transform.rotate(
                    key: const ValueKey('flapping-bird-right-wing'),
                    angle: angles.wingAngle * 0.5,
                    alignment: const Alignment(0.18, 0.15),
                    child: Transform.scale(
                      scaleX: angles.wingFold,
                      alignment: Alignment.centerLeft,
                      child: ClipPath(
                        clipper: const _FlappingWingClipper(isLeft: false),
                        child: _birdImage(size),
                      ),
                    ),
                  ),
                  // Central body, head & tail
                  ClipPath(
                    key: const ValueKey('flapping-bird-body'),
                    clipper: const _FlappingBodyClipper(),
                    child: _birdImage(size),
                  ),
                  // Primary wing (foreground)
                  Transform.rotate(
                    key: const ValueKey('flapping-bird-left-wing'),
                    angle: -angles.wingAngle,
                    alignment: const Alignment(0.22, 0.20),
                    child: Transform.scale(
                      scaleX: angles.wingFold,
                      alignment: Alignment.centerRight,
                      child: ClipPath(
                        clipper: const _FlappingWingClipper(isLeft: true),
                        child: _birdImage(size),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (widget.semanticLabel != null) {
      content = Semantics(
        label: widget.semanticLabel,
        image: true,
        liveRegion: true,
        child: content,
      );
    }

    return RepaintBoundary(child: content);
  }

  Widget _birdImage(double size) {
    // Select the optimal resolution tier based on rendered size
    final asset = size <= 32
        ? 'assets/branding/rad_flying_bird_64.png'
        : (size <= 72
              ? 'assets/branding/rad_flying_bird_128.png'
              : (size <= 160
                    ? 'assets/branding/rad_flying_bird_256.png'
                    : 'assets/branding/rad_flying_bird_512.png'));

    return Image.asset(
      asset,
      fit: BoxFit.contain,
      filterQuality: size <= 32 ? FilterQuality.medium : FilterQuality.high,
      color: widget.color,
      colorBlendMode: widget.color != null ? BlendMode.srcIn : null,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to silhouette if multi-resolution asset is unavailable
        return Image.asset(
          'assets/branding/rad_bird_silhouette.png',
          fit: BoxFit.contain,
          color: widget.color,
          colorBlendMode: widget.color != null ? BlendMode.srcIn : null,
          excludeFromSemantics: true,
        );
      },
    );
  }

  /// Calculates the wing angle, body bobbing, and wing fold across the 6 stages.
  _Kinetics _computeKinetics(double t) {
    // Stage 1: Wings Up (0.00 -> 0.16)
    // Stage 2: Start Down (0.16 -> 0.33)
    // Stage 3: Mid Flap (0.33 -> 0.50)
    // Stage 4: Wings Down (0.50 -> 0.66)
    // Stage 5: Return Up (0.66 -> 0.83)
    // Stage 6: Continue Cycle (0.83 -> 1.00)

    double wingAngle;
    double bodyDy;
    double wingFold = 1.0;

    if (t < 0.166) {
      // Stage 1: Peak elevation -> preparing downstroke
      final s = t / 0.166;
      wingAngle = -0.30 + s * 0.08;
      bodyDy = 0.025 - s * 0.01;
    } else if (t < 0.333) {
      // Stage 2: Start downstroke
      final s = (t - 0.166) / 0.167;
      wingAngle = -0.22 + s * 0.22;
      bodyDy = 0.015 - s * 0.025;
    } else if (t < 0.500) {
      // Stage 3: Mid downstroke -> high lift
      final s = (t - 0.333) / 0.167;
      wingAngle = 0.00 + s * 0.34;
      bodyDy = -0.010 - s * 0.025;
    } else if (t < 0.666) {
      // Stage 4: Full downstroke apex
      final s = (t - 0.500) / 0.166;
      wingAngle = 0.34 - s * 0.12;
      bodyDy = -0.035 + s * 0.015;
    } else if (t < 0.833) {
      // Stage 5: Return upstroke with slight fold
      final s = (t - 0.666) / 0.167;
      wingAngle = 0.22 - s * 0.32;
      wingFold = 0.93 + s * 0.04;
      bodyDy = -0.020 + s * 0.03;
    } else {
      // Stage 6: Continue cycle returning to wings up
      final s = (t - 0.833) / 0.167;
      wingAngle = -0.10 - s * 0.20;
      wingFold = 0.97 + s * 0.03;
      bodyDy = 0.010 + s * 0.015;
    }

    return _Kinetics(wingAngle: wingAngle, bodyDy: bodyDy, wingFold: wingFold);
  }
}

class _Kinetics {
  const _Kinetics({
    required this.wingAngle,
    required this.bodyDy,
    required this.wingFold,
  });

  final double wingAngle;
  final double bodyDy;
  final double wingFold;
}

class _FlappingWingClipper extends CustomClipper<Path> {
  const _FlappingWingClipper({required this.isLeft});

  final bool isLeft;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    if (isLeft) {
      // Primary sweeping wing feathers
      return Path()
        ..moveTo(0, 0)
        ..lineTo(w * 0.70, 0)
        ..lineTo(w * 0.68, h * 0.45)
        ..lineTo(w * 0.60, h * 0.58)
        ..lineTo(w * 0.50, h * 0.65)
        ..lineTo(w * 0.35, h * 0.62)
        ..lineTo(0, h * 0.62)
        ..close();
    } else {
      // Secondary radiant wing layer
      return Path()
        ..moveTo(w * 0.18, 0)
        ..lineTo(w * 0.68, 0)
        ..lineTo(w * 0.68, h * 0.45)
        ..lineTo(w * 0.52, h * 0.56)
        ..lineTo(w * 0.18, h * 0.48)
        ..close();
    }
  }

  @override
  bool shouldReclip(covariant _FlappingWingClipper oldClipper) =>
      oldClipper.isLeft != isLeft;
}

class _FlappingBodyClipper extends CustomClipper<Path> {
  const _FlappingBodyClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.58, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(0, h * 0.58)
      ..lineTo(w * 0.35, h * 0.58)
      ..lineTo(w * 0.50, h * 0.60)
      ..lineTo(w * 0.58, h * 0.52)
      ..lineTo(w * 0.62, h * 0.40)
      ..lineTo(w * 0.65, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _FlappingBodyClipper oldClipper) => false;
}

class _BirdAuraPainter extends CustomPainter {
  const _BirdAuraPainter({required this.progress, this.color});

  final double progress;
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final auraColor = color ?? AppColors.primaryRed;

    // Diffuse light follows the layered feathers; no outlined ring or orb.
    final breath = (math.sin(progress * math.pi * 2) + 1) * .025;
    final glowPaint = Paint()
      ..color = auraColor.withValues(alpha: .16 + breath)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * .14);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * .70,
        height: size.height * .45,
      ),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BirdAuraPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
