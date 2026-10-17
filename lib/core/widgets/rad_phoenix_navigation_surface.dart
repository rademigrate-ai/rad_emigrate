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

  // Large system text wraps rather than being clipped by the slim line box.
  static int labelLines(BuildContext context) {
    final size = MediaQuery.textScalerOf(context).scale(11);
    // At 200% on a 320 px screen, "AI Assistant" needs three lines while
    // preserving 48 px neighboring touch targets and the requested text size.
    return size > 19.8 ? 3 : (size > 14.3 ? 2 : 1);
  }

  static double labelHeight(BuildContext context) {
    final scale = (MediaQuery.textScalerOf(context).scale(11) / 11).clamp(
      1.0,
      double.infinity,
    );
    return 18 * scale * labelLines(context);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // A 64 px glass body plus the raised bird's headroom. The entire 76 px
    // destination is interactive; device-safe insets remain outside it.
    final height = 58.0 + labelHeight(context);
    const clipper = _PhoenixSurfaceClipper();

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final centreWidth = (constraints.maxWidth * 0.28).clamp(
                88.0,
                104.0,
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
                          alpha: dark ? 0.32 : 0.10,
                        ),
                        elevation: dark ? 8 : 3,
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
                                        const Color(0xFF272936)
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
                                      ).withValues(alpha: dark ? 0.06 : 0.02),
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
    final rect = Rect.fromLTRB(1, 11, size.width - 1, size.height - 1);
    return Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(32)));
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
