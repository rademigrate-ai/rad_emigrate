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
    this.showEditorialRule = true,
  });

  final Widget child;
  final bool dark;
  final Color accent;
  final bool compact;
  final bool showEditorialRule;

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
                  showEditorialRule: showEditorialRule,
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
              letterSpacing: 1.15,
            ),
          ),
        ),
      ],
    );
  }
}
