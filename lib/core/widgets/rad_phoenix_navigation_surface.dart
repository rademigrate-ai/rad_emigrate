import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Continuous glass capsule; the original RAD Phoenix rises above its top edge.
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
                  clipBehavior: Clip.none,
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
                          filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: dark
                                    ? [
                                        const Color(0xFF253344)
                                            .withValues(alpha: 0.72),
                                        const Color(0xFF101925)
                                            .withValues(alpha: 0.86),
                                      ]
                                    : [
                                        Colors.white.withValues(alpha: 0.76),
                                        const Color(0xFFE9F1FC)
                                            .withValues(alpha: 0.86),
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
                                ? Colors.white.withValues(alpha: 0.16)
                                : Colors.white.withValues(alpha: 0.90),
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
    final rect = Rect.fromLTRB(1, 12, size.width - 1, size.height - 1);
    return Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(42)));
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
