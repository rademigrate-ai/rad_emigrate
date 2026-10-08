import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_motion.dart';

/// The visual density appropriate for a real pending operation.
enum RadLoadingSize { fullScreen, section, compact }

/// A lifecycle-safe, branded pending-operation indicator for RAD.
///
/// The full and section variants use a painted Earth with an orbiting copy of
/// the official RAD bird. The compact variant intentionally skips the globe so
/// inline feedback remains light on mobile and in dense product surfaces.
class RadLoadingIndicator extends StatefulWidget {
  const RadLoadingIndicator({
    super.key,
    this.size = RadLoadingSize.section,
    required this.label,
    this.message,
    this.active = true,
    this.dark = false,
  });

  final RadLoadingSize size;
  final String label;
  final String? message;
  final bool active;
  final bool dark;

  @override
  State<RadLoadingIndicator> createState() => _RadLoadingIndicatorState();
}

class _RadLoadingIndicatorState extends State<RadLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _isAnimating = false;

  Duration get _orbitDuration => switch (widget.size) {
    RadLoadingSize.fullScreen => const Duration(seconds: 9),
    RadLoadingSize.section => const Duration(seconds: 8),
    RadLoadingSize.compact => const Duration(milliseconds: 1450),
  };

  bool get _shouldAnimate =>
      widget.active &&
      !AppMotion.reduceMotion(context) &&
      TickerMode.valuesOf(context).enabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _orbitDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant RadLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.size != widget.size) {
      _controller.duration = _orbitDuration;
    }
    if (oldWidget.active != widget.active || oldWidget.size != widget.size) {
      _syncMotion();
    }
  }

  void _syncMotion() {
    if (_shouldAnimate && !_isAnimating) {
      _controller.repeat();
      _isAnimating = true;
      return;
    }
    if (!_shouldAnimate && _isAnimating) {
      _controller.stop();
      _controller.value = 0.16;
      _isAnimating = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dimensions = _dimensionsFor(widget.size);
    final scene = RepaintBoundary(
      child: SizedBox.square(
        dimension: dimensions.scene,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RadLoadingScenePainter(
                  progress: _controller,
                  variant: widget.size,
                  dark: widget.dark,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              child: _RadBirdMark(dimension: dimensions.bird),
              builder: (context, child) {
                final position = _orbitPosition(
                  progress: _controller.value,
                  variant: widget.size,
                  side: dimensions.scene,
                );
                final angle = _birdAngle(
                  progress: _controller.value,
                  variant: widget.size,
                );
                final depth = math.sin(angle);
                final scale = 0.84 + ((depth + 1) * 0.1);
                return Transform.translate(
                  offset: position,
                  child: Transform.rotate(
                    angle: angle * 0.32,
                    child: Transform.scale(scale: scale, child: child),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );

    return Semantics(
      label: widget.label,
      liveRegion: true,
      container: true,
      child: ExcludeSemantics(
        child: switch (widget.size) {
          RadLoadingSize.compact => scene,
          _ => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              scene,
              if (widget.message != null) ...[
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(
                    widget.message!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: widget.dark
                          ? const Color(0xFFD2E4E8)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        },
      ),
    );
  }
}

/// Compact RAD feedback for a local, non-button pending operation.
class RadInlineLoading extends StatelessWidget {
  const RadInlineLoading({
    super.key,
    required this.label,
    this.active = true,
    this.dark = false,
  });

  final String label;
  final bool active;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return RadLoadingIndicator(
      size: RadLoadingSize.compact,
      label: label,
      active: active,
      dark: dark,
    );
  }
}

class _RadLoadingDimensions {
  const _RadLoadingDimensions({required this.scene, required this.bird});

  final double scene;
  final double bird;
}

_RadLoadingDimensions _dimensionsFor(RadLoadingSize variant) {
  return switch (variant) {
    RadLoadingSize.fullScreen => const _RadLoadingDimensions(
      scene: 226,
      bird: 52,
    ),
    RadLoadingSize.section => const _RadLoadingDimensions(scene: 156, bird: 37),
    RadLoadingSize.compact => const _RadLoadingDimensions(scene: 42, bird: 25),
  };
}

Offset _orbitPosition({
  required double progress,
  required RadLoadingSize variant,
  required double side,
}) {
  final angle = _birdAngle(progress: progress, variant: variant);
  final compact = variant == RadLoadingSize.compact;
  final horizontal = side * (compact ? 0.28 : 0.37);
  final vertical = side * (compact ? 0.14 : 0.18);
  return Offset(math.cos(angle) * horizontal, math.sin(angle) * vertical);
}

double _birdAngle({required double progress, required RadLoadingSize variant}) {
  final phase = variant == RadLoadingSize.compact ? 0.15 : 0.78;
  return (progress * math.pi * 2) - phase;
}

class _RadBirdMark extends StatelessWidget {
  const _RadBirdMark({required this.dimension});

  final double dimension;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: dimension,
      height: dimension,
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(
          AppColors.primaryRed,
          BlendMode.srcIn,
        ),
        child: Image.asset(
          'assets/branding/rad_bird_silhouette.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _RadLoadingScenePainter extends CustomPainter {
  _RadLoadingScenePainter({
    required this.progress,
    required this.variant,
    required this.dark,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final RadLoadingSize variant;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final side = math.min(size.width, size.height);
    final compact = variant == RadLoadingSize.compact;
    final phase = progress.value * math.pi * 2;

    if (compact) {
      _paintCompactOrbit(canvas, center, side, phase);
      return;
    }

    final radius = side * (variant == RadLoadingSize.fullScreen ? 0.285 : 0.3);
    final globe = Rect.fromCircle(center: center, radius: radius);
    final atmosphere = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.38, -0.48),
        radius: 0.94,
        colors: dark
            ? const [Color(0xFF245C74), Color(0xFF123B50), Color(0xFF071D2C)]
            : const [Color(0xFFE2FAFB), Color(0xFF8FCFD2), Color(0xFF3A7F8C)],
      ).createShader(globe);
    final outerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF5DE1DB).withValues(alpha: dark ? 0.2 : 0.16),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.48));

    canvas.drawCircle(center, radius * 1.48, outerGlow);
    canvas.drawCircle(center, radius, atmosphere);
    canvas.save();
    canvas.clipPath(Path()..addOval(globe));
    _paintGlobeContours(canvas, globe, phase);
    _paintAtmosphericBands(canvas, globe, phase);
    canvas.restore();

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = const Color(0xFF93F4ED).withValues(alpha: dark ? 0.8 : 0.7),
    );
    _paintOrbit(canvas, center, side, phase);
  }

  void _paintCompactOrbit(
    Canvas canvas,
    Offset center,
    double side,
    double phase,
  ) {
    final orbit = Rect.fromCenter(
      center: center,
      width: side * 0.78,
      height: side * 0.37,
    );
    canvas.drawOval(
      orbit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..color = AppColors.teal.withValues(alpha: 0.7),
    );
    final markerAngle = phase + 1.4;
    final marker = Offset(
      center.dx + math.cos(markerAngle) * side * 0.29,
      center.dy + math.sin(markerAngle) * side * 0.13,
    );
    canvas.drawCircle(
      marker,
      1.8,
      Paint()..color = const Color(0xFF92F4EF).withValues(alpha: 0.92),
    );
  }

  void _paintGlobeContours(Canvas canvas, Rect globe, double phase) {
    final continent = Paint()
      ..color = const Color(0xFF70E4D9).withValues(alpha: dark ? 0.24 : 0.31);
    final secondary = Paint()
      ..color = const Color(0xFFC1FFFF).withValues(alpha: dark ? 0.12 : 0.19);

    final major = Path()
      ..moveTo(globe.left + globe.width * 0.16, globe.top + globe.height * 0.39)
      ..cubicTo(
        globe.left + globe.width * 0.3,
        globe.top + globe.height * 0.22,
        globe.left + globe.width * 0.56,
        globe.top + globe.height * 0.28,
        globe.left + globe.width * 0.63,
        globe.top + globe.height * 0.45,
      )
      ..cubicTo(
        globe.left + globe.width * 0.7,
        globe.top + globe.height * 0.59,
        globe.left + globe.width * 0.56,
        globe.top + globe.height * 0.78,
        globe.left + globe.width * 0.39,
        globe.top + globe.height * 0.72,
      )
      ..cubicTo(
        globe.left + globe.width * 0.22,
        globe.top + globe.height * 0.67,
        globe.left + globe.width * 0.1,
        globe.top + globe.height * 0.51,
        globe.left + globe.width * 0.16,
        globe.top + globe.height * 0.39,
      );
    canvas.save();
    canvas.translate(math.sin(phase * 0.45) * globe.width * 0.035, 0);
    canvas.drawPath(major, continent);
    final island = Path()
      ..moveTo(globe.left + globe.width * 0.63, globe.top + globe.height * 0.25)
      ..quadraticBezierTo(
        globe.left + globe.width * 0.84,
        globe.top + globe.height * 0.35,
        globe.left + globe.width * 0.74,
        globe.top + globe.height * 0.5,
      )
      ..quadraticBezierTo(
        globe.left + globe.width * 0.62,
        globe.top + globe.height * 0.42,
        globe.left + globe.width * 0.63,
        globe.top + globe.height * 0.25,
      );
    canvas.drawPath(island, secondary);
    canvas.restore();
  }

  void _paintAtmosphericBands(Canvas canvas, Rect globe, double phase) {
    final wire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFD0FFFF).withValues(alpha: dark ? 0.32 : 0.42);
    for (final factor in [-0.48, -0.22, 0.18, 0.45]) {
      final y = globe.center.dy + globe.height * factor * 0.72;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(globe.center.dx, y),
          width: globe.width * (1 - factor.abs() * 0.16),
          height: globe.height * 0.15,
        ),
        wire,
      );
    }
    canvas.save();
    canvas.translate(globe.center.dx, globe.center.dy);
    canvas.rotate(phase * 0.16);
    for (final scale in [0.38, 0.68]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: globe.width * scale,
          height: globe.height,
        ),
        wire,
      );
    }
    canvas.restore();
  }

  void _paintOrbit(Canvas canvas, Offset center, double side, double phase) {
    final orbit = Rect.fromCenter(
      center: center,
      width: side * 0.78,
      height: side * 0.37,
    );
    final trail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF79F1EB).withValues(alpha: dark ? 0.62 : 0.7);
    canvas.drawArc(orbit, 0.18, math.pi * 1.25, false, trail);
    canvas.drawArc(
      orbit,
      math.pi * 1.52,
      math.pi * 0.35,
      false,
      trail..color = trail.color.withValues(alpha: 0.24),
    );

    final pulse = Offset(
      center.dx + math.cos(phase + 1.7) * side * 0.37,
      center.dy + math.sin(phase + 1.7) * side * 0.18,
    );
    canvas.drawCircle(
      pulse,
      variant == RadLoadingSize.fullScreen ? 3.4 : 2.5,
      Paint()..color = const Color(0xFF8DFFF8),
    );
  }

  @override
  bool shouldRepaint(covariant _RadLoadingScenePainter oldDelegate) {
    return oldDelegate.variant != variant || oldDelegate.dark != dark;
  }
}
