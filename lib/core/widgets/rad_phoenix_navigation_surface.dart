import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Reserve a shared label region, including wrapping at larger system text sizes.
double radNavigationLabelHeight(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
  return scale <= 1.2 ? 18 * scale : 11 * scale * 1.2 * 3;
}

/// Adaptive capsule navigation with a gently raised RAD assistant destination.
/// Insets are outside the glass so no destination sits beneath the home gesture.
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
    // 80 logical pixels keeps all five always-visible labels on one baseline.
    // Grow the capsule rather than shrinking text for accessibility scaling.
    final height = 62 + radNavigationLabelHeight(context);
    final capsuleRadius = BorderRadius.circular(height / 2);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final centreWidth = (constraints.maxWidth * 0.24).clamp(
                72.0,
                96.0,
              );
              return SizedBox(
                key: const ValueKey('rad-phoenix-navigation-surface'),
                height: height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: capsuleRadius,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: dark ? 0.34 : 0.14,
                              ),
                              blurRadius: dark ? 24 : 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: capsuleRadius,
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: capsuleRadius,
                                border: Border.all(
                                  color: dark
                                      ? Colors.white.withValues(alpha: 0.18)
                                      : Colors.white.withValues(alpha: 0.78),
                                  width: 0.8,
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: dark
                                      ? [
                                          const Color(0xFF282A31)
                                              .withValues(alpha: 0.82),
                                          const Color(0xFF111319)
                                              .withValues(alpha: 0.90),
                                        ]
                                      : [
                                          Colors.white.withValues(alpha: 0.82),
                                          const Color(0xFFF4F6FA)
                                              .withValues(alpha: 0.90),
                                        ],
                                ),
                              ),
                            ),
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
