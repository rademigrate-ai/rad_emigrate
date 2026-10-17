import 'app_back_button.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/premium_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'rad_glass_surface.dart';
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
    this.showEditorialRule = false,
  });

  final Widget child;
  final bool dark;
  final Color accent;
  final bool compact;
  final bool showEditorialRule;

  @override
  Widget build(BuildContext context) {
    final effectiveDark =
        dark || Theme.of(context).brightness == Brightness.dark;
    final tokens = effectiveDark ? PremiumTokens.dark : context.premium;
    return DecoratedBox(
      decoration: BoxDecoration(color: tokens.canvas),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CanvasGridPainter(
                  dark: effectiveDark,
                  accent: accent,
                  compact: compact,
                  showEditorialRule: showEditorialRule,
                ),
              ),
            ),
          ),
          Material(color: Colors.transparent, child: child),
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
    final color = context.premium.accentForeground;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 28, height: 2, color: AppColors.primaryRed),
        const SizedBox(width: 10),
        // The kicker must never overflow narrow mobile headers; ellipsize
        // instead of breaking layout when the label is long.
        Flexible(
          child: Text(
            '$index / $label',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
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
    this.heroVisual,
    this.backFallback,
  });

  final Widget form;
  final String eyebrow;
  final String title;
  final String body;
  final Widget localeControl;
  final Widget? heroVisual;
  final String? backFallback;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;
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
                  child: heroVisual ?? const RadOrbit(size: 330),
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
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: heroVisual ?? const RadOrbit(size: 174),
                  ),
                ),
              ),
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
                  RadGlassSurface(
                    padding: EdgeInsets.all(wide ? 32 : 24),
                    child: form,
                  ),
                  if (!wide) ...[
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        eyebrow,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: context.premium.mutedText,
                          letterSpacing: 0,
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

    final frame = Scaffold(
      body: wide
          ? Row(
              children: [
                Expanded(flex: 11, child: visual),
                Expanded(flex: 10, child: formSurface),
              ],
            )
          : Column(
              children: [
                SizedBox(
                  height:
                      MediaQuery.sizeOf(context).height < 700 ||
                          MediaQuery.viewInsetsOf(context).bottom > 0
                      ? 120
                      : 220,
                  child: visual,
                ),
                Expanded(child: formSurface),
              ],
            ),
    );
    return backFallback == null
        ? frame
        : BackFallbackScope(fallback: backFallback!, child: frame);
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
    this.dark = false,
  });

  final Widget kicker;
  final String title;
  final String body;
  final Widget? trailing;
  final Widget? footer;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final tokens = dark ? PremiumTokens.dark : context.premium;
    final foreground = tokens.text;
    final secondary = tokens.mutedText;
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.tablet;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.hero),
      child: PremiumCanvas(
        dark: dark,
        accent: AppColors.teal,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: tokens.heroGradient,
            border: Border.all(color: tokens.border),
          ),
          child: Stack(
            children: [
              if (trailing != null && !compact)
                PositionedDirectional(
                  end: -18,
                  bottom: -40,
                  child: Opacity(opacity: dark ? 0.88 : 0.6, child: trailing!),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (compact && trailing != null)
                    Row(
                      children: [
                        Expanded(child: kicker),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: FittedBox(child: trailing!),
                        ),
                      ],
                    )
                  else
                    kicker,
                  const SizedBox(height: 22),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: foreground,
                            fontSize: compact ? 28 : 32,
                            height: 1.4,
                            letterSpacing: 0,
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
                  if (footer != null) ...[const SizedBox(height: 24), footer!],
                ],
              ),
            ],
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
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.explore, l10n.documents, l10n.cases];
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
    required this.showEditorialRule,
  });

  final bool dark;
  final Color accent;
  final bool compact;
  final bool showEditorialRule;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accent.withValues(alpha: dark ? 0.06 : 0.025),
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
    if (showEditorialRule) {
      final red = Paint()
        ..color = AppColors.primaryRed.withValues(alpha: dark ? 0.12 : 0.06)
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(size.width * 0.06, size.height * 0.87),
        Offset(size.width * 0.46, size.height * 0.87),
        red,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasGridPainter oldDelegate) =>
      oldDelegate.dark != dark ||
      oldDelegate.accent != accent ||
      oldDelegate.compact != compact ||
      oldDelegate.showEditorialRule != showEditorialRule;
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
