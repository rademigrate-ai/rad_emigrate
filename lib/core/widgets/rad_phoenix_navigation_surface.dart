import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Floating glass navigation with a raised centre for the original RAD Phoenix.
/// Insets are outside the glass: no destination can sit beneath the home gesture.
class RadPhoenixNavigationSurface extends StatelessWidget {
  const RadPhoenixNavigationSurface({
    super.key,
    required this.leading,
    required this.trailing,
    required this.phoenix,
  }) : assert(leading.length == 2 && trailing.length == 2);

  final List<Widget> leading;
  final List<Widget> trailing;
  final Widget phoenix;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textScale = MediaQuery.textScalerOf(context).scale(11) / 11;
    // Two-line Persian labels have a taller line box than Latin labels. Grow
    // the surface instead of shrinking text when the user increases text size.
    final height = 96.0 + ((textScale - 1).clamp(0.0, 3.0) * 44);
    const clipper = _PhoenixSurfaceClipper();

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final centreWidth = (constraints.maxWidth * 0.30).clamp(
                88.0,
                118.0,
              );
              return SizedBox(
                key: const ValueKey('rad-phoenix-navigation-surface'),
                height: height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: PhysicalShape(
                        clipper: clipper,
                        color: Colors.transparent,
                        shadowColor: Colors.black.withValues(
                          alpha: dark ? 0.48 : 0.16,
                        ),
                        elevation: dark ? 12 : 6,
                        clipBehavior: Clip.antiAlias,
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: dark
                                    ? [
                                        const Color(0xFF222328)
                                            .withValues(alpha: 0.83),
                                        const Color(0xFF101115)
                                            .withValues(alpha: 0.92),
                                      ]
                                    : [
                                        Colors.white.withValues(alpha: 0.88),
                                        const Color(0xFFF0F2F6)
                                            .withValues(alpha: 0.96),
                                      ],
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: centreWidth * 1.32,
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: const Alignment(0, -0.28),
                                    radius: 0.62,
                                    colors: [
                                      const Color(
                                        0xFFFF1835,
                                      ).withValues(alpha: dark ? 0.13 : 0.05),
                                      const Color(0xFFFF1835)
                                          .withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _PhoenixBorderPainter(
                            dark
                                ? Colors.white.withValues(alpha: 0.18)
                                : const Color(0xFF6A7383)
                                      .withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final destination in leading)
                          Expanded(child: destination),
                        SizedBox(width: centreWidth, child: phoenix),
                        for (final destination in trailing)
                          Expanded(child: destination),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PhoenixSurfaceClipper extends CustomClipper<Path> {
  const _PhoenixSurfaceClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(32, 24)
      ..lineTo(w * 0.31, 24)
      ..cubicTo(w * 0.40, 24, w * 0.40, 1, w * 0.50, 1)
      ..cubicTo(w * 0.60, 1, w * 0.60, 24, w * 0.69, 24)
      ..lineTo(w - 32, 24)
      ..quadraticBezierTo(w - 1, 24, w - 1, 55)
      ..lineTo(w - 1, h - 32)
      ..quadraticBezierTo(w - 1, h - 1, w - 32, h - 1)
      ..lineTo(32, h - 1)
      ..quadraticBezierTo(1, h - 1, 1, h - 32)
      ..lineTo(1, 55)
      ..quadraticBezierTo(1, 24, 32, 24)
      ..close();
  }

  @override
  bool shouldReclip(_PhoenixSurfaceClipper oldClipper) => false;
}

class _PhoenixBorderPainter extends CustomPainter {
  const _PhoenixBorderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      const _PhoenixSurfaceClipper().getClip(size),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_PhoenixBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}
