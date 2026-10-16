import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_motion.dart';

enum RadAiBirdState { idle, listening, thinking, responding, newMessage }

/// Stateful RAD AI Assistant identity built directly from canonical Reference 1.
///
/// Features the translucent crimson right-facing flying bird with layered
/// wing feathers, dark eye, pointed beak, and flowing tail. Each state implements
/// the exact visual cues and kinetics specified in Reference 2.
class RadAiBird extends StatefulWidget {
  const RadAiBird({
    super.key,
    required this.state,
    required this.semanticLabel,
    this.size = 176,
    this.showBackgroundOrb = true,
  });

  final RadAiBirdState state;
  final String semanticLabel;
  final double size;
  final bool showBackgroundOrb;

  @override
  State<RadAiBird> createState() => _RadAiBirdState();
}

class _RadAiBirdState extends State<RadAiBird>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration get _duration => switch (widget.state) {
    RadAiBirdState.idle => const Duration(milliseconds: 2600),
    RadAiBirdState.listening => const Duration(milliseconds: 1200),
    RadAiBirdState.thinking => const Duration(milliseconds: 1800),
    RadAiBirdState.responding => const Duration(milliseconds: 880),
    RadAiBirdState.newMessage => const Duration(milliseconds: 1100),
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(
      const AssetImage('assets/branding/rad_flying_bird_512.png'),
      context,
    );
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
      _controller.value = 0.35;
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
                  RadAiBirdState.idle => pose * 2.2,
                  RadAiBirdState.listening => pose.abs() * -1.8,
                  RadAiBirdState.thinking => 3.0 + math.sin(t * 0.5) * 1.0,
                  RadAiBirdState.responding => pose * 1.5,
                  RadAiBirdState.newMessage => pose.abs() * -3.5,
                };

                final wingAngle = switch (widget.state) {
                  RadAiBirdState.idle => pose * 0.035,
                  RadAiBirdState.listening => pose * 0.065,
                  RadAiBirdState.thinking => -0.04 + math.sin(t * 0.5) * 0.015,
                  RadAiBirdState.responding => pose * 0.16,
                  RadAiBirdState.newMessage => pose * 0.12,
                };

                final scale = switch (widget.state) {
                  RadAiBirdState.idle => 1.0 + pose * 0.015,
                  RadAiBirdState.listening => 1.02 + pose * 0.01,
                  RadAiBirdState.thinking => 0.96 + math.sin(t * 0.5) * 0.01,
                  RadAiBirdState.responding => 1.04 + pose * 0.02,
                  RadAiBirdState.newMessage => 1.02 + pose * 0.02,
                };

                return CustomPaint(
                  painter: _BirdStatePainter(
                    state: widget.state,
                    progress: _controller.value,
                    showOrb: widget.showBackgroundOrb,
                  ),
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(
                      scale: scale,
                      child: reduced
                          ? child
                          : _ArticulatedBird(
                              key: const ValueKey('articulated-rad-bird'),
                              wingAngle: wingAngle,
                              isResponding:
                                  widget.state == RadAiBirdState.responding,
                            ),
                    ),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.all(widget.size * 0.08),
                child: Image.asset(
                  'assets/branding/rad_flying_bird_512.png',
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

/// Articulated canonical bird layers using Reference 1 anatomy:
/// - Primary wing feathers (foreground) pivoting naturally at the shoulder joint.
/// - Secondary radiant wing layer (background) for depth and responding spread.
/// - Head facing right, dark eye, delicate pointed beak, breast, and flowing tail.
class _ArticulatedBird extends StatelessWidget {
  const _ArticulatedBird({
    super.key,
    required this.wingAngle,
    this.isResponding = false,
  });

  final double wingAngle;
  final bool isResponding;

  static const _asset = 'assets/branding/rad_flying_bird_512.png';

  Widget _image() => Image.asset(
    _asset,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    excludeFromSemantics: true,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Secondary radiant wing layer (background)
          Transform.rotate(
            key: const ValueKey('rad-bird-right-wing'),
            angle: isResponding ? wingAngle * 1.3 + 0.16 : wingAngle * 0.45,
            alignment: const Alignment(0.18, 0.15),
            child: Transform.scale(
              scale: isResponding ? 1.06 : 1.0,
              child: ClipPath(
                clipper: const _BirdLayerClipper(_BirdLayer.secondaryWing),
                clipBehavior: Clip.hardEdge,
                child: _image(),
              ),
            ),
          ),
          // Body, head facing right with eye & beak, and flowing tail feathers
          ClipPath(
            key: const ValueKey('rad-bird-body'),
            clipper: const _BirdLayerClipper(_BirdLayer.body),
            clipBehavior: Clip.hardEdge,
            child: _image(),
          ),
          // Primary sweeping wing feathers (foreground)
          Transform.rotate(
            key: const ValueKey('rad-bird-left-wing'),
            angle: -wingAngle,
            alignment: const Alignment(0.22, 0.20),
            child: ClipPath(
              clipper: const _BirdLayerClipper(_BirdLayer.primaryWing),
              clipBehavior: Clip.hardEdge,
              child: _image(),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BirdLayer { primaryWing, secondaryWing, body }

class _BirdLayerClipper extends CustomClipper<Path> {
  const _BirdLayerClipper(this.layer);

  final _BirdLayer layer;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return switch (layer) {
      _BirdLayer.primaryWing =>
        Path()
          ..moveTo(0, 0)
          ..lineTo(w * 0.70, 0)
          ..lineTo(w * 0.68, h * 0.45)
          ..lineTo(w * 0.60, h * 0.58)
          ..lineTo(w * 0.50, h * 0.65)
          ..lineTo(w * 0.35, h * 0.62)
          ..lineTo(0, h * 0.62)
          ..close(),
      _BirdLayer.secondaryWing =>
        Path()
          ..moveTo(w * 0.18, 0)
          ..lineTo(w * 0.68, 0)
          ..lineTo(w * 0.68, h * 0.45)
          ..lineTo(w * 0.52, h * 0.56)
          ..lineTo(w * 0.18, h * 0.48)
          ..close(),
      _BirdLayer.body =>
        Path()
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
          ..close(),
    };
  }

  @override
  bool shouldReclip(covariant _BirdLayerClipper oldClipper) =>
      oldClipper.layer != layer;
}

/// Paints the Reference 2 translucent red glass sphere (orb) with curved
/// specular rim highlight, base floor ripples, and state-specific cues.
class _BirdStatePainter extends CustomPainter {
  const _BirdStatePainter({
    required this.state,
    required this.progress,
    this.showOrb = true,
  });

  final RadAiBirdState state;
  final double progress;
  final bool showOrb;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final orbCenter = Offset(center.dx, center.dy + size.height * 0.02);
    final orbRadius = size.width * 0.38;

    if (showOrb) {
      // 1. Base translucent glass orb (from Reference 2)
      final orbRect = Rect.fromCircle(center: orbCenter, radius: orbRadius);
      final orbGradient = RadialGradient(
        center: const Alignment(0, 0.1),
        radius: 0.85,
        colors: [
          AppColors.primaryRed.withValues(alpha: 0.32),
          AppColors.primaryRed.withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      );

      final orbPaint = Paint()
        ..shader = orbGradient.createShader(orbRect)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(orbCenter, orbRadius, orbPaint);

      // Ambient soft glow behind orb
      final glowPaint = Paint()
        ..color = AppColors.primaryRed.withValues(alpha: 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.08);
      canvas.drawCircle(orbCenter, orbRadius * 1.05, glowPaint);

      // Specular bright curved rim highlight along bottom hemisphere (Reference 2)
      final rimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.8, size.width * 0.024)
        ..color = const Color(0xFFFF2442).withValues(alpha: 0.90)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      canvas.drawArc(
        Rect.fromCircle(center: orbCenter, radius: orbRadius * 0.98),
        math.pi * 0.22,
        math.pi * 0.56,
        false,
        rimPaint,
      );

      // Ambient floor reflection ripples at the base of the orb (Reference 2)
      final rippleCenter = Offset(
        orbCenter.dx,
        orbCenter.dy + orbRadius * 0.94,
      );
      final ripplePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.primaryRed.withValues(alpha: 0.28);
      canvas.drawOval(
        Rect.fromCenter(
          center: rippleCenter,
          width: orbRadius * 1.35,
          height: orbRadius * 0.32,
        ),
        ripplePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(rippleCenter.dx, rippleCenter.dy + 3),
          width: orbRadius * 0.85,
          height: orbRadius * 0.20,
        ),
        ripplePaint..color = AppColors.primaryRed.withValues(alpha: 0.16),
      );
    }

    // 2. State-specific visual indicators (from Reference 2)
    if (state == RadAiBirdState.idle) {
      if (showOrb) {
        final breathAlpha =
            0.08 + (math.sin(progress * math.pi * 2) + 1) * 0.04;
        canvas.drawCircle(
          orbCenter,
          orbRadius * 1.12,
          Paint()
            ..color = AppColors.primaryRed.withValues(alpha: breathAlpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.10),
        );
      }
    } else if (state == RadAiBirdState.listening) {
      // Reference 2 State 2: 7 vertical red rounded soundwave bars above the bird
      final waveCenterY = size.height * 0.13;
      final barWidth = math.max(2.2, size.width * 0.018);
      final barSpacing = size.width * 0.040;
      const barCount = 7;
      final startX = center.dx - ((barCount - 1) / 2) * barSpacing;
      final barPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFF2442);

      for (var i = 0; i < barCount; i++) {
        final distFromCenter = (i - (barCount - 1) / 2).abs();
        final maxH = size.height * (0.14 - distFromCenter * 0.016);
        final minH = size.height * 0.028;
        final waveVal =
            (math.sin(progress * math.pi * 2 * 2.8 + i * 0.90) + 1) / 2;
        final barH = minH + (maxH - minH) * waveVal;
        final x = startX + i * barSpacing;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x, waveCenterY),
              width: barWidth,
              height: barH,
            ),
            Radius.circular(barWidth / 2),
          ),
          barPaint,
        );
      }
    } else if (state == RadAiBirdState.thinking) {
      // Reference 2 State 3: 3 glowing red dots (...) above the bird's head
      final dotCenterY = size.height * 0.13;
      final dotSpacing = size.width * 0.058;
      final dotRadius = size.width * 0.024;
      for (var i = 0; i < 3; i++) {
        final x = center.dx + (i - 1) * dotSpacing;
        final pulse =
            (math.sin(progress * math.pi * 2 * 1.8 - i * 0.95) + 1) / 2;
        final alpha = 0.35 + pulse * 0.65;
        final r = dotRadius * (0.80 + pulse * 0.35);
        canvas.drawCircle(
          Offset(x, dotCenterY),
          r,
          Paint()..color = const Color(0xFFFF2442).withValues(alpha: alpha),
        );
        // Soft aura on each dot
        canvas.drawCircle(
          Offset(x, dotCenterY),
          r * 1.6,
          Paint()
            ..color = AppColors.primaryRed.withValues(alpha: alpha * 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    } else if (state == RadAiBirdState.responding) {
      // Reference 2 State 4: Radiant expanding aura rings
      final auraAlpha = 0.20 + (math.sin(progress * math.pi * 2) + 1) * 0.10;
      canvas.drawCircle(
        orbCenter,
        orbRadius * 1.25,
        Paint()
          ..color = AppColors.primaryRed.withValues(alpha: auraAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.12),
      );

      for (var i = 1; showOrb && i <= 2; i++) {
        final waveProg = (progress + i * 0.5) % 1.0;
        final waveRadius = orbRadius * (0.85 + waveProg * 0.45);
        final waveAlpha = (1.0 - waveProg) * 0.45;
        canvas.drawCircle(
          orbCenter,
          waveRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.2, size.width * 0.012)
            ..color = const Color(0xFFFF2442).withValues(alpha: waveAlpha),
        );
      }
    } else if (state == RadAiBirdState.newMessage) {
      // Reference 2 State 5: Circular notification beacon with white diamond at top-right
      final badgeCenter = Offset(size.width * 0.76, size.height * 0.16);
      final badgeRadius = size.width * 0.065;

      // Outer radar pulse
      final pulseProg = progress % 1.0;
      final pulseRadius = badgeRadius * (1.1 + pulseProg * 1.2);
      final pulseAlpha = (1.0 - pulseProg) * 0.45;
      canvas.drawCircle(
        badgeCenter,
        pulseRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = AppColors.primaryRed.withValues(alpha: pulseAlpha),
      );

      // Solid red badge
      canvas.drawCircle(
        badgeCenter,
        badgeRadius,
        Paint()..color = const Color(0xFFFF1835),
      );

      // White diamond inside beacon badge (from Reference 2)
      final d = badgeRadius * 0.48;
      final diamondPath = Path()
        ..moveTo(badgeCenter.dx, badgeCenter.dy - d)
        ..lineTo(badgeCenter.dx + d * 0.68, badgeCenter.dy)
        ..lineTo(badgeCenter.dx, badgeCenter.dy + d)
        ..lineTo(badgeCenter.dx - d * 0.68, badgeCenter.dy)
        ..close();
      canvas.drawPath(diamondPath, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _BirdStatePainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.progress != progress ||
      oldDelegate.showOrb != showOrb;
}
