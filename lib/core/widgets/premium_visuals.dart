import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_motion.dart';
import 'motion_primitives.dart';
import 'rad_brand.dart';

/// Original RAD visual vocabulary used by high-impact product surfaces.
///
/// The artwork is painted from primitives rather than borrowed assets. It uses
/// the RAD mark unchanged and never communicates a visa outcome or statistic.
class PremiumCanvas extends StatelessWidget {
  const PremiumCanvas({
    super.key,
    required this.child,
    this.dark = false,
    this.accent = AppColors.teal,
    this.compact = false,
  });

  final Widget child;
  final bool dark;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final background = dark ? AppColors.midnight : const Color(0xFFF3F7F8);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF071620), Color(0xFF0B2632), Color(0xFF071620)]
              : const [Color(0xFFF7FAFA), Color(0xFFEAF4F5), Color(0xFFF9FBFB)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CanvasGridPainter(
                  dark: dark,
                  accent: accent,
                  compact: compact,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class EditorialKicker extends StatelessWidget {
  const EditorialKicker({
    super.key,
    required this.index,
    required this.label,
    this.dark = false,
  });

  final String index;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? const Color(0xFF8EE9E4) : AppColors.teal;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 28, height: 2, color: AppColors.primaryRed),
        const SizedBox(width: 10),
        Text(
          '$index / $label',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.15,
          ),
        ),
      ],
    );
  }
}

class RadOrbit extends StatefulWidget {
  const RadOrbit({
    super.key,
    this.size = 300,
    this.active = true,
    this.showBrand = true,
    this.dark = true,
  });

  final double size;
  final bool active;
  final bool showBrand;
  final bool dark;

  @override
  State<RadOrbit> createState() => _RadOrbitState();
}

class _RadOrbitState extends State<RadOrbit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.active && !AppMotion.reduceMotion(context)) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant RadOrbit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (widget.active && !AppMotion.reduceMotion(context)) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _OrbitPainter(
              progress: _controller.value,
              dark: widget.dark,
            ),
            child: widget.showBrand
                ? Center(
                    child: Transform.rotate(
                      angle: -_controller.value * 0.04,
                      child: const RadBrand(
                        size: RadBrandSize.medium,
                        showInstituteName: false,
                        darkSurface: true,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
    return AppMotion.reduceMotion(context) ? content : content;
  }
}

class AuthCinematicFrame extends StatelessWidget {
  const AuthCinematicFrame({
    super.key,
    required this.form,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.localeControl,
  });

  final Widget form;
  final String eyebrow;
  final String title;
  final String body;
  final Widget localeControl;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final theme = Theme.of(context);
    final visual = PremiumCanvas(
      dark: true,
      accent: AppColors.teal,
      child: Padding(
        padding: EdgeInsets.fromLTRB(wide ? 56 : 24, 28, wide ? 56 : 24, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditorialKicker(index: '01', label: eyebrow, dark: true),
            if (wide) ...[
              const Spacer(),
              Align(
                alignment: AlignmentDirectional.center,
                child: MotionReveal(
                  duration: AppMotion.emphasized,
                  offset: const Offset(0, 0.06),
                  child: const RadOrbit(size: 330),
                ),
              ),
              const Spacer(),
              MotionStagger(
                index: 1,
                child: Text(
                  title,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 42,
                    height: 1.12,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              MotionStagger(
                index: 2,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    body,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFFC4D5DE),
                      height: 1.65,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _RouteLegend(),
            ] else ...[
              const Spacer(),
              const Align(
                alignment: AlignmentDirectional.center,
                child: RadOrbit(size: 132),
              ),
              const Spacer(),
            ],
          ],
        ),
      ),
    );

    final formSurface = PremiumCanvas(
      accent: AppColors.cyan,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              wide ? 52 : 24,
              24,
              wide ? 52 : 24,
              32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 456),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: localeControl,
                  ),
                  const SizedBox(height: 26),
                  Container(
                    padding: EdgeInsets.all(wide ? 32 : 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A083344),
                          blurRadius: 38,
                          offset: Offset(0, 20),
                        ),
                      ],
                    ),
                    child: form,
                  ),
                  if (!wide) ...[
                    const SizedBox(height: 26),
                    Center(
                      child: Text(
                        eyebrow,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.teal,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      body: wide
          ? Row(
              children: [
                Expanded(flex: 11, child: visual),
                Expanded(flex: 10, child: formSurface),
              ],
            )
          : Column(
              children: [
                SizedBox(height: 288, child: visual),
                Expanded(child: formSurface),
              ],
            ),
    );
  }
}

class PremiumHeroPanel extends StatelessWidget {
  const PremiumHeroPanel({
    super.key,
    required this.kicker,
    required this.title,
    required this.body,
    this.trailing,
    this.footer,
    this.dark = true,
  });

  final Widget kicker;
  final String title;
  final String body;
  final Widget? trailing;
  final Widget? footer;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final foreground = dark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final secondary = dark
        ? const Color(0xFFBDD2D7)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final height = footer == null
        ? (compact ? 320.0 : 292.0)
        : (compact ? 410.0 : 350.0);
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: PremiumCanvas(
          dark: dark,
          accent: AppColors.teal,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              border: Border.all(
                color: dark
                    ? const Color(0xFF4CBFBD).withValues(alpha: 0.32)
                    : const Color(0xFFBBD5D7),
              ),
            ),
            child: Stack(
              children: [
                if (trailing != null && !compact)
                  PositionedDirectional(
                    end: -18,
                    bottom: -40,
                    child: Opacity(
                      opacity: dark ? 0.88 : 0.6,
                      child: trailing!,
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    kicker,
                    const SizedBox(height: 22),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              color: foreground,
                              fontSize: 34,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: Text(
                        body,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(color: secondary, height: 1.55),
                      ),
                    ),
                    if (footer != null) ...[
                      const SizedBox(height: 24),
                      footer!,
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteLegend extends StatelessWidget {
  const _RouteLegend();

  @override
  Widget build(BuildContext context) {
    const labels = ['Explore', 'Organize', 'Follow'];
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (var index = 0; index < labels.length; index++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '0${index + 1}  ${labels[index]}',
              style: const TextStyle(
                color: Color(0xFFD8E8EA),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.45,
              ),
            ),
          ),
      ],
    );
  }
}

class _CanvasGridPainter extends CustomPainter {
  const _CanvasGridPainter({
    required this.dark,
    required this.accent,
    required this.compact,
  });

  final bool dark;
  final Color accent;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = (dark ? Colors.white : AppColors.navy).withValues(
        alpha: dark ? 0.045 : 0.035,
      )
      ..strokeWidth = 1;
    final step = compact ? 52.0 : 72.0;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), grid);
    }
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accent.withValues(alpha: dark ? 0.20 : 0.14),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.85, size.height * 0.12),
              radius: math.max(size.width, size.height) * 0.48,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.12),
      math.max(size.width, size.height) * 0.48,
      glow,
    );
    final red = Paint()
      ..color = AppColors.primaryRed.withValues(alpha: dark ? 0.38 : 0.24)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width * 0.06, size.height * 0.87),
      Offset(size.width * 0.46, size.height * 0.87),
      red,
    );
  }

  @override
  bool shouldRepaint(covariant _CanvasGridPainter oldDelegate) =>
      oldDelegate.dark != dark ||
      oldDelegate.accent != accent ||
      oldDelegate.compact != compact;
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.progress, required this.dark});

  final double progress;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minSide = math.min(size.width, size.height);
    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..color = (dark ? const Color(0xFF9AE7E1) : AppColors.teal).withValues(
        alpha: 0.48,
      );
    final muted = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = (dark ? Colors.white : AppColors.navy).withValues(alpha: 0.18);
    canvas.drawCircle(center, minSide * 0.43, muted);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: minSide * 0.94,
        height: minSide * 0.47,
      ),
      orbit,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(progress * math.pi * 2);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: minSide * 0.62,
        height: minSide * 0.96,
      ),
      orbit,
    );
    final dot = Paint()..color = AppColors.primaryRed;
    canvas.drawCircle(Offset(minSide * 0.31, 0), 5, dot);
    final tealDot = Paint()..color = const Color(0xFF65DED6);
    canvas.drawCircle(Offset(-minSide * 0.47, 0), 3, tealDot);
    canvas.restore();
    final node = Paint()..color = const Color(0xFF53D9D2);
    canvas.drawCircle(Offset(center.dx, minSide * 0.07), 3.5, node);
    canvas.drawCircle(
      Offset(center.dx + minSide * 0.39, center.dy + minSide * 0.17),
      3.5,
      node,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.dark != dark;
}
