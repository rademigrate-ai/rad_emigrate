import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// 24-hour interactive timeline. Dragging updates [onScrub] with a UTC instant
/// for the selected local hour relative to "today" in the reference zone.
class TimelineScrubber extends StatelessWidget {
  const TimelineScrubber({
    super.key,
    required this.selectedHour,
    required this.onChanged,
  });

  /// 0–24 fractional hour.
  final double selectedHour;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) {
                  final x = (d.localPosition.dx).clamp(0.0, width);
                  onChanged((x / width) * 24);
                },
                onTapDown: (d) {
                  final x = d.localPosition.dx.clamp(0.0, width);
                  onChanged((x / width) * 24);
                },
                child: CustomPaint(
                  painter: _TimelinePainter(selectedHour: selectedHour),
                  size: Size(width, 48),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('00:00',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                Text('06:00',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                Text('12:00',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                Text('18:00',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                Text('24:00',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.selectedHour});
  final double selectedHour;

  @override
  void paint(Canvas canvas, Size size) {
    final trackY = size.height / 2;

    // Day/night gradient band
    final rect = Rect.fromLTWH(0, trackY - 8, size.width, 16);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF1A2740),
          Color(0xFF3A5A8A),
          Color(0xFFE8B84A),
          Color(0xFF3A5A8A),
          Color(0xFF1A2740),
        ],
        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );

    // Tick marks every 3 hours
    final tickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    for (var h = 0; h <= 24; h += 3) {
      final x = (h / 24) * size.width;
      canvas.drawLine(
        Offset(x, trackY - 12),
        Offset(x, trackY + 12),
        tickPaint,
      );
    }

    // Selected marker
    final x = (selectedHour.clamp(0, 24) / 24) * size.width;
    final markerPaint = Paint()
      ..color = AppColors.primaryRed
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, trackY), 9, markerPaint);
    canvas.drawCircle(
      Offset(x, trackY),
      9,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Glow
    canvas.drawCircle(
      Offset(x, trackY),
      16,
      Paint()
        ..color = AppColors.primaryRed.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.selectedHour != selectedHour;
}
