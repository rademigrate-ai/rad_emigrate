import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_motion.dart';

/// The visual context in which the shared RAD Earth-and-bird identity appears.
///
/// Phase 1 uses [loginHero] only. The remaining variants express the approved
/// visual family without migrating Splash or loading surfaces before the Login
/// Hero visual gate is approved.
enum RadEarthBirdVariant {
  loginHero,
  splash,
  fullScreenLoading,
  sectionLoading,
  compactLoading,
}

/// A lifecycle-safe, visual-only RAD Earth-and-bird scene.
///
/// The parent owns product state and decides whether the scene is [active].
/// This component owns only the paint, asset treatment, animation lifecycle,
/// reduced-motion behavior, and a single accessible label.
class RadEarthBirdScene extends StatefulWidget {
  const RadEarthBirdScene({
    super.key,
    required this.variant,
    required this.semanticLabel,
    this.size,
    this.active = true,
    this.dark = true,
  });

  final RadEarthBirdVariant variant;
  final String semanticLabel;
  final double? size;
  final bool active;
  final bool dark;

  @override
  State<RadEarthBirdScene> createState() => _RadEarthBirdSceneState();
}

class _RadEarthBirdSceneState extends State<RadEarthBirdScene>
    with SingleTickerProviderStateMixin {
  static const _restingProgress = 0.16;

  late final AnimationController _controller;
  var _isAnimating = false;

  Duration get _orbitDuration => switch (widget.variant) {
    RadEarthBirdVariant.loginHero => AppMotion.ambient,
    RadEarthBirdVariant.splash => const Duration(seconds: 12),
    RadEarthBirdVariant.fullScreenLoading => const Duration(seconds: 11),
    RadEarthBirdVariant.sectionLoading => const Duration(seconds: 10),
    RadEarthBirdVariant.compactLoading => const Duration(milliseconds: 1500),
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
  void didUpdateWidget(covariant RadEarthBirdScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variant != widget.variant) {
      _controller.duration = _orbitDuration;
    }
    if (oldWidget.active != widget.active ||
        oldWidget.variant != widget.variant) {
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
      _controller.value = _restingProgress;
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
    final dimensions = _SceneDimensions.forVariant(widget.variant);
    final targetSize = widget.size ?? dimensions.scene;
    final isCompact = widget.variant == RadEarthBirdVariant.compactLoading;

    return Semantics(
      label: widget.semanticLabel,
      image: true,
      container: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sceneSize = _sceneSizeWithin(targetSize, constraints);
              final birdSize = dimensions.bird * (sceneSize / targetSize);
              return SizedBox.square(
                dimension: sceneSize,
                child: AnimatedBuilder(
                  animation: _controller,
                  child: _RadBirdMark(dimension: birdSize),
                  builder: (context, bird) {
                    final orbit = _OrbitGeometry.fromProgress(
                      progress: _controller.value,
                      side: sceneSize,
                      compact: isCompact,
                    );
                    final birdLayer = _PositionedBird(
                      geometry: orbit,
                      child: bird!,
                    );

                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _BackdropOrbitPainter(
                              progress: _controller,
                              variant: widget.variant,
                              dark: widget.dark,
                            ),
                            isComplex: !isCompact,
                            willChange: !AppMotion.reduceMotion(context),
                          ),
                        ),
                        if (!isCompact && !orbit.isForeground) birdLayer,
                        if (!isCompact)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _EarthPainter(
                                progress: _controller,
                                variant: widget.variant,
                                dark: widget.dark,
                              ),
                              isComplex: true,
                              willChange: !AppMotion.reduceMotion(context),
                            ),
                          ),
                        if (!isCompact)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ForegroundOrbitPainter(
                                progress: _controller,
                                dark: widget.dark,
                              ),
                              willChange: !AppMotion.reduceMotion(context),
                            ),
                          ),
                        if (isCompact || orbit.isForeground) birdLayer,
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

double _sceneSizeWithin(double targetSize, BoxConstraints constraints) {
  var available = targetSize;
  if (constraints.maxWidth.isFinite) {
    available = math.min(available, constraints.maxWidth);
  }
  if (constraints.maxHeight.isFinite) {
    available = math.min(available, constraints.maxHeight);
  }
  return math.max(0, available);
}

class _SceneDimensions {
  const _SceneDimensions({required this.scene, required this.bird});

  final double scene;
  final double bird;

  static _SceneDimensions forVariant(RadEarthBirdVariant variant) {
    return switch (variant) {
      RadEarthBirdVariant.loginHero => const _SceneDimensions(
        scene: 330,
        bird: 78,
      ),
      RadEarthBirdVariant.splash => const _SceneDimensions(
        scene: 270,
        bird: 64,
      ),
      RadEarthBirdVariant.fullScreenLoading => const _SceneDimensions(
        scene: 280,
        bird: 68,
      ),
      RadEarthBirdVariant.sectionLoading => const _SceneDimensions(
        scene: 168,
        bird: 43,
      ),
      RadEarthBirdVariant.compactLoading => const _SceneDimensions(
        scene: 48,
        bird: 29,
      ),
    };
  }
}

class _OrbitGeometry {
  const _OrbitGeometry({
    required this.position,
    required this.bank,
    required this.scale,
    required this.isForeground,
  });

  final Offset position;
  final double bank;
  final double scale;
  final bool isForeground;

  factory _OrbitGeometry.fromProgress({
    required double progress,
    required double side,
    required bool compact,
  }) {
    // Deterministic, seamlessly looping flight: multiple low-frequency
    // harmonics produce natural variation without per-frame random jumps.
    // Compact loading deliberately retains its simple, predictable orbit.
    final time = progress * math.pi * 2;
    final phase = time - 0.78;
    final wander = compact ? 0.0 : math.sin(time * 3 + 0.65) * 0.085;
    final altitude = compact ? 0.0 : math.sin(time * 2 - 0.4) * 0.065;
    final horizontalRadius = side * (compact ? 0.3 : 0.385);
    final verticalRadius = side * (compact ? 0.15 : 0.2);
    final flightPhase = phase + wander;
    final depth = math.sin(flightPhase);
    final x = math.cos(flightPhase) * horizontalRadius;
    final y = (math.sin(flightPhase) + altitude) * verticalRadius;
    // Tangent-based banking follows turns smoothly, with no flips.
    final phaseRate = 1 + (compact ? 0.0 : math.cos(time * 3 + 0.65) * 0.255);
    final dx = -math.sin(flightPhase) * phaseRate * horizontalRadius;
    final dy = (math.cos(flightPhase) * phaseRate +
            (compact ? 0.0 : math.cos(time * 2 - 0.4) * 0.13)) *
        verticalRadius;
    final turn = math.atan2(dy, dx);
    return _OrbitGeometry(
      position: Offset((side / 2) + x, (side / 2) + y),
      // Preserve the bird's original forward-facing silhouette.
      bank: compact ? -0.12 + math.cos(phase) * 0.24
          : (math.sin(turn) * 0.20 + math.sin(time * 2) * 0.035),
      scale: compact ? 1 : 0.8 + ((depth + 1) * 0.13),
      isForeground: compact || depth >= 0,
    );
  }
}

class _PositionedBird extends StatelessWidget {
  const _PositionedBird({required this.geometry, required this.child});

  final _OrbitGeometry geometry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final renderBox = child is SizedBox ? child as SizedBox : null;
    final dimension = renderBox?.width ?? 48.0;
    return Positioned(
      left: geometry.position.dx - (dimension / 2),
      top: geometry.position.dy - (dimension / 2),
      child: Transform.rotate(
        angle: geometry.bank,
        alignment: Alignment.center,
        child: Transform.scale(
          scale: geometry.scale,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

class _RadBirdMark extends StatelessWidget {
  const _RadBirdMark({required this.dimension});

  final double dimension;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
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

class _BackdropOrbitPainter extends CustomPainter {
  _BackdropOrbitPainter({
    required this.progress,
    required this.variant,
    required this.dark,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final RadEarthBirdVariant variant;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final side = math.min(size.width, size.height);
    final compact = variant == RadEarthBirdVariant.compactLoading;
    final phase = progress.value * math.pi * 2;

    if (compact) {
      _paintCompactOrbit(canvas, center, side, phase);
      return;
    }

    final outerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = (dark ? const Color(0xFFB1EDE8) : AppColors.teal).withValues(
        alpha: dark ? 0.16 : 0.18,
      );
    final orbitalLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.25
      ..color = (dark ? const Color(0xFF84EAE3) : AppColors.teal).withValues(
        alpha: dark ? 0.42 : 0.48,
      );

    canvas.drawCircle(center, side * 0.43, outerRing);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: side * 0.94, height: side * 0.47),
      orbitalLine,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.54);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: side * 0.64,
        height: side * 0.98,
      ),
      orbitalLine..color = orbitalLine.color.withValues(alpha: 0.28),
    );
    canvas.restore();

    final markerOrbit = Rect.fromCenter(
      center: center,
      width: side * 0.94,
      height: side * 0.47,
    );
    final marker = Offset(
      center.dx + (math.cos(phase + 0.9) * markerOrbit.width * 0.5),
      center.dy + (math.sin(phase + 0.9) * markerOrbit.height * 0.5),
    );
    _paintGlowDot(
      canvas,
      marker,
      radius: side * 0.016,
      color: const Color(0xFF65ECE4),
      glowAlpha: 0.22,
    );
    _paintGlowDot(
      canvas,
      Offset(center.dx - (side * 0.36), center.dy - (side * 0.18)),
      radius: side * 0.012,
      color: const Color(0xFF55D9D2),
      glowAlpha: 0.16,
    );
    _paintGlowDot(
      canvas,
      Offset(center.dx + (side * 0.34), center.dy + (side * 0.15)),
      radius: side * 0.011,
      color: AppColors.primaryRed,
      glowAlpha: 0.18,
    );
  }

  void _paintCompactOrbit(
    Canvas canvas,
    Offset center,
    double side,
    double phase,
  ) {
    final orbit = Rect.fromCenter(
      center: center,
      width: side * 0.82,
      height: side * 0.39,
    );
    canvas.drawOval(
      orbit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..color = AppColors.teal.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropOrbitPainter oldDelegate) {
    return oldDelegate.variant != variant || oldDelegate.dark != dark;
  }
}

class _EarthPainter extends CustomPainter {
  _EarthPainter({
    required this.progress,
    required this.variant,
    required this.dark,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final RadEarthBirdVariant variant;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final side = math.min(size.width, size.height);
    final radius = side * _earthRadiusFor(variant);
    final globe = Rect.fromCircle(center: center, radius: radius);

    _paintOuterAtmosphere(canvas, center, radius, globe);
    _paintOcean(canvas, center, radius, globe);

    canvas.save();
    canvas.clipPath(Path()..addOval(globe));
    _paintLandAndLights(canvas, globe, progress.value);
    _paintCloudDepth(canvas, globe, progress.value);
    _paintTerminator(canvas, globe);
    _paintSpecularLight(canvas, globe);
    canvas.restore();

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, radius * 0.018)
      ..shader = SweepGradient(
        colors: [
          const Color(0xFF8EF8EE).withValues(alpha: dark ? 0.15 : 0.28),
          const Color(0xFF5DE9E1).withValues(alpha: dark ? 0.94 : 0.82),
          const Color(0xFFB0FFFF).withValues(alpha: dark ? 0.46 : 0.42),
          const Color(0xFF8EF8EE).withValues(alpha: dark ? 0.15 : 0.28),
        ],
      ).createShader(globe);
    canvas.drawCircle(center, radius, rim);
  }

  void _paintOuterAtmosphere(
    Canvas canvas,
    Offset center,
    double radius,
    Rect globe,
  ) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF42DED9).withValues(alpha: dark ? 0.31 : 0.2),
          const Color(0xFF1A9FB1).withValues(alpha: dark ? 0.1 : 0.06),
          Colors.transparent,
        ],
        stops: const [0, 0.57, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.42));
    canvas.drawCircle(center, radius * 1.42, glow);

    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, radius * 0.035)
      ..color = const Color(0xFF59E8E3).withValues(alpha: dark ? 0.17 : 0.13);
    canvas.drawCircle(center, radius * 1.055, halo);
  }

  void _paintOcean(Canvas canvas, Offset center, double radius, Rect globe) {
    final ocean = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.32, -0.42),
        radius: 1.05,
        colors: dark
            ? const [
                Color(0xFF2C7B9A),
                Color(0xFF174D76),
                Color(0xFF0B294F),
                Color(0xFF041729),
              ]
            : const [
                Color(0xFFB8F5F0),
                Color(0xFF5FB8C3),
                Color(0xFF2F718D),
                Color(0xFF18496B),
              ],
        stops: const [0, 0.33, 0.72, 1],
      ).createShader(globe);
    canvas.drawCircle(center, radius, ocean);

    final oceanBloom = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.32, -0.48),
        colors: [
          const Color(0xFFD9FFFF).withValues(alpha: dark ? 0.17 : 0.2),
          Colors.transparent,
        ],
      ).createShader(globe);
    canvas.drawCircle(center, radius, oceanBloom);
  }

  void _paintLandAndLights(Canvas canvas, Rect globe, double progressValue) {
    final shift = globe.width * progressValue;
    for (var copy = -1; copy <= 1; copy++) {
      canvas.save();
      canvas.translate((copy * globe.width) - shift, 0);
      _paintLandmasses(canvas, globe);
      _paintCityLights(canvas, globe);
      canvas.restore();
    }
  }

  void _paintLandmasses(Canvas canvas, Rect globe) {
    Offset point(double x, double y) =>
        Offset(globe.left + (globe.width * x), globe.top + (globe.height * y));

    final land = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF79C9B1), Color(0xFF2D8174), Color(0xFF1C5F67)]
            : const [Color(0xFF80CDBB), Color(0xFF4BA796), Color(0xFF267B80)],
      ).createShader(globe);
    final coast = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, globe.width * 0.008)
      ..color = const Color(0xFFB2FFF1).withValues(alpha: dark ? 0.35 : 0.42);

    final americas = Path()
      ..moveTo(point(0.13, 0.18).dx, point(0.13, 0.18).dy)
      ..cubicTo(
        point(0.25, 0.1).dx,
        point(0.25, 0.1).dy,
        point(0.34, 0.16).dx,
        point(0.34, 0.16).dy,
        point(0.31, 0.27).dx,
        point(0.31, 0.27).dy,
      )
      ..cubicTo(
        point(0.24, 0.35).dx,
        point(0.24, 0.35).dy,
        point(0.27, 0.42).dx,
        point(0.27, 0.42).dy,
        point(0.2, 0.5).dx,
        point(0.2, 0.5).dy,
      )
      ..cubicTo(
        point(0.22, 0.6).dx,
        point(0.22, 0.6).dy,
        point(0.18, 0.72).dx,
        point(0.18, 0.72).dy,
        point(0.23, 0.82).dx,
        point(0.23, 0.82).dy,
      )
      ..cubicTo(
        point(0.17, 0.9).dx,
        point(0.17, 0.9).dy,
        point(0.12, 0.78).dx,
        point(0.12, 0.78).dy,
        point(0.09, 0.65).dx,
        point(0.09, 0.65).dy,
      )
      ..cubicTo(
        point(0.12, 0.53).dx,
        point(0.12, 0.53).dy,
        point(0.05, 0.45).dx,
        point(0.05, 0.45).dy,
        point(0.1, 0.36).dx,
        point(0.1, 0.36).dy,
      )
      ..cubicTo(
        point(0.08, 0.27).dx,
        point(0.08, 0.27).dy,
        point(0.13, 0.18).dx,
        point(0.13, 0.18).dy,
        point(0.13, 0.18).dx,
        point(0.13, 0.18).dy,
      );

    final eurasiaAfrica = Path()
      ..moveTo(point(0.48, 0.19).dx, point(0.48, 0.19).dy)
      ..cubicTo(
        point(0.6, 0.05).dx,
        point(0.6, 0.05).dy,
        point(0.86, 0.1).dx,
        point(0.86, 0.1).dy,
        point(0.93, 0.24).dx,
        point(0.93, 0.24).dy,
      )
      ..cubicTo(
        point(0.89, 0.34).dx,
        point(0.89, 0.34).dy,
        point(0.75, 0.33).dx,
        point(0.75, 0.33).dy,
        point(0.72, 0.42).dx,
        point(0.72, 0.42).dy,
      )
      ..cubicTo(
        point(0.79, 0.5).dx,
        point(0.79, 0.5).dy,
        point(0.72, 0.58).dx,
        point(0.72, 0.58).dy,
        point(0.63, 0.54).dx,
        point(0.63, 0.54).dy,
      )
      ..cubicTo(
        point(0.61, 0.73).dx,
        point(0.61, 0.73).dy,
        point(0.53, 0.9).dx,
        point(0.53, 0.9).dy,
        point(0.43, 0.74).dx,
        point(0.43, 0.74).dy,
      )
      ..cubicTo(
        point(0.41, 0.58).dx,
        point(0.41, 0.58).dy,
        point(0.34, 0.48).dx,
        point(0.34, 0.48).dy,
        point(0.42, 0.4).dx,
        point(0.42, 0.4).dy,
      )
      ..cubicTo(
        point(0.39, 0.3).dx,
        point(0.39, 0.3).dy,
        point(0.48, 0.19).dx,
        point(0.48, 0.19).dy,
        point(0.48, 0.19).dx,
        point(0.48, 0.19).dy,
      );

    final australia = Path()
      ..moveTo(point(0.79, 0.72).dx, point(0.79, 0.72).dy)
      ..quadraticBezierTo(
        point(0.85, 0.65).dx,
        point(0.9, 0.66).dy,
        point(0.93, 0.77).dx,
        point(0.93, 0.77).dy,
      )
      ..quadraticBezierTo(
        point(0.87, 0.87).dx,
        point(0.87, 0.87).dy,
        point(0.77, 0.82).dx,
        point(0.77, 0.82).dy,
      )
      ..quadraticBezierTo(
        point(0.75, 0.76).dx,
        point(0.75, 0.76).dy,
        point(0.79, 0.72).dx,
        point(0.79, 0.72).dy,
      );

    for (final continent in [americas, eurasiaAfrica, australia]) {
      canvas.drawPath(continent, land);
      canvas.drawPath(continent, coast);
    }
  }

  void _paintCityLights(Canvas canvas, Rect globe) {
    final cities = [
      const Offset(0.18, 0.31),
      const Offset(0.2, 0.48),
      const Offset(0.18, 0.68),
      const Offset(0.51, 0.28),
      const Offset(0.57, 0.34),
      const Offset(0.62, 0.39),
      const Offset(0.69, 0.33),
      const Offset(0.72, 0.44),
      const Offset(0.56, 0.6),
      const Offset(0.84, 0.77),
    ];
    for (final city in cities) {
      final location = Offset(
        globe.left + (city.dx * globe.width),
        globe.top + (city.dy * globe.height),
      );
      _paintGlowDot(
        canvas,
        location,
        radius: math.max(0.85, globe.width * 0.008),
        color: const Color(0xFFFFD29A),
        glowAlpha: dark ? 0.22 : 0.14,
      );
    }
  }

  void _paintCloudDepth(Canvas canvas, Rect globe, double progressValue) {
    final cloud = Paint()
      ..color = const Color(0xFFE9FFFF).withValues(alpha: dark ? 0.075 : 0.1);
    final drift = math.sin(progressValue * math.pi * 2) * globe.width * 0.04;
    for (final cloudShape in [
      Rect.fromCenter(
        center: Offset(
          globe.left + (globe.width * 0.31) + drift,
          globe.top + (globe.height * 0.27),
        ),
        width: globe.width * 0.26,
        height: globe.height * 0.055,
      ),
      Rect.fromCenter(
        center: Offset(
          globe.left + (globe.width * 0.65) + drift,
          globe.top + (globe.height * 0.53),
        ),
        width: globe.width * 0.31,
        height: globe.height * 0.06,
      ),
      Rect.fromCenter(
        center: Offset(
          globe.left + (globe.width * 0.43) + drift,
          globe.top + (globe.height * 0.75),
        ),
        width: globe.width * 0.22,
        height: globe.height * 0.045,
      ),
    ]) {
      canvas.drawOval(cloudShape, cloud);
    }
  }

  void _paintTerminator(Canvas canvas, Rect globe) {
    final terminator = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          const Color(0xFF001221).withValues(alpha: dark ? 0.16 : 0.1),
          const Color(0xFF00101D).withValues(alpha: dark ? 0.7 : 0.45),
        ],
        stops: const [0.15, 0.6, 1],
      ).createShader(globe);
    canvas.drawOval(globe, terminator);
  }

  void _paintSpecularLight(Canvas canvas, Rect globe) {
    final specular = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.38, -0.48),
        radius: 0.54,
        colors: [
          const Color(0xFFD8FFFF).withValues(alpha: dark ? 0.22 : 0.28),
          Colors.transparent,
        ],
      ).createShader(globe);
    canvas.drawOval(globe, specular);
  }

  @override
  bool shouldRepaint(covariant _EarthPainter oldDelegate) {
    return oldDelegate.variant != variant || oldDelegate.dark != dark;
  }
}

class _ForegroundOrbitPainter extends CustomPainter {
  _ForegroundOrbitPainter({required this.progress, required this.dark})
    : super(repaint: progress);

  final Animation<double> progress;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final side = math.min(size.width, size.height);
    final orbit = Rect.fromCenter(
      center: center,
      width: side * 0.94,
      height: side * 0.47,
    );
    final cyanTrail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5
      ..color = const Color(0xFF72F0E9).withValues(alpha: dark ? 0.74 : 0.68);
    final redTrail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.15
      ..color = AppColors.primaryRed.withValues(alpha: dark ? 0.62 : 0.54);

    canvas.drawArc(orbit, 0.16, math.pi * 0.67, false, cyanTrail);
    canvas.drawArc(orbit, math.pi * 0.96, math.pi * 0.23, false, redTrail);

    final phase = progress.value * math.pi * 2;
    final dot = Offset(
      center.dx + (math.cos(phase + 0.38) * orbit.width * 0.5),
      center.dy + (math.sin(phase + 0.38) * orbit.height * 0.5),
    );
    _paintGlowDot(
      canvas,
      dot,
      radius: side * 0.014,
      color: AppColors.primaryRed,
      glowAlpha: 0.22,
    );
  }

  @override
  bool shouldRepaint(covariant _ForegroundOrbitPainter oldDelegate) {
    return oldDelegate.dark != dark;
  }
}

double _earthRadiusFor(RadEarthBirdVariant variant) {
  return switch (variant) {
    RadEarthBirdVariant.loginHero => 0.315,
    RadEarthBirdVariant.splash => 0.31,
    RadEarthBirdVariant.fullScreenLoading => 0.305,
    RadEarthBirdVariant.sectionLoading => 0.3,
    RadEarthBirdVariant.compactLoading => 0,
  };
}

void _paintGlowDot(
  Canvas canvas,
  Offset center, {
  required double radius,
  required Color color,
  required double glowAlpha,
}) {
  final glow = Paint()
    ..color = color.withValues(alpha: glowAlpha)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 2.4);
  canvas.drawCircle(center, radius * 2.3, glow);
  canvas.drawCircle(center, radius, Paint()..color = color);
}
