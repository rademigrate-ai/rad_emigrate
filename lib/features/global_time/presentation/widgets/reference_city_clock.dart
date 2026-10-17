import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/city.dart';
import '../../domain/local_date_format.dart';
import '../../domain/timezone_engine.dart';
import '../providers/global_time_controller.dart';

DateTime _time(City city, DateTime? atUtc) => atUtc == null
    ? TimezoneEngine.nowInCity(city)
    : tz.TZDateTime.from(
        atUtc.toUtc(),
        TimezoneEngine.locationOf(city.timezone),
      );

class ReferenceCityRow extends StatelessWidget {
  const ReferenceCityRow({
    super.key,
    required this.city,
    required this.languageCode,
    this.atUtc,
    required this.onTap,
  });
  final City city;
  final String languageCode;
  final DateTime? atUtc;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final now = _time(city, atUtc);
    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360 &&
              MediaQuery.textScalerOf(context).scale(14) > 20) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (city.flagEmoji != null) ...[
                      Text(
                        city.flagEmoji!,
                        style: const TextStyle(fontSize: 29),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        city.localizedName(languageCode),
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Icon(Icons.more_vert, size: 18),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  formatLocalTime(now),
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  formatLocalDate(now, languageCode),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            );
          }
          return Row(
            children: [
              if (city.flagEmoji != null) ...[
                Text(city.flagEmoji!, style: const TextStyle(fontSize: 29)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  city.localizedName(languageCode),
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatLocalTime(now),
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatLocalDate(now, languageCode),
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.more_vert, size: 18),
            ],
          );
        },
      ),
    );
  }
}

class ReferenceCityDetail extends ConsumerWidget {
  const ReferenceCityDetail({super.key, required this.city});
  final City city;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(globalTimeControllerProvider);
    final ctrl = ref.read(globalTimeControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final now = _time(city, state.scrubUtc);
    final saved = state.favorites.any((c) => c.id == city.id);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          children: [
            if (city.flagEmoji != null)
              Text(city.flagEmoji!, style: const TextStyle(fontSize: 42)),
            Text(
              city.localizedName(lang),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(city.timezone, style: Theme.of(context).textTheme.bodySmall),
            Text(
              TimezoneEngine.offsetLabel(city.timezone, at: state.scrubUtc),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            Container(
              width: 204,
              height: 204,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.premium.surfaceElevated,
                border: Border.all(color: context.premium.border),
                boxShadow: context.premium.shadow,
              ),
              child: CustomPaint(
                painter: _ClockFace(
                  time: now,
                  foreground: context.premium.text,
                  muted: context.premium.mutedText,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              formatLocalTime(now),
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              formatLocalDate(now, lang),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(saved ? Icons.star : Icons.star_outline),
                label: Text(saved ? l10n.delete : l10n.addCity),
                onPressed: () async {
                  if (saved) {
                    await ctrl.removeFavorite(city.id);
                  } else {
                    await ctrl.addFavorite(city);
                  }
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClockFace extends CustomPainter {
  const _ClockFace({
    required this.time,
    required this.foreground,
    required this.muted,
  });
  final DateTime time;
  final Color foreground;
  final Color muted;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final tick = Paint()
      ..color = muted
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 - math.pi / 2;
      canvas.drawLine(
        center + Offset(math.cos(a), math.sin(a)) * (radius - 13),
        center + Offset(math.cos(a), math.sin(a)) * (radius - 20),
        tick,
      );
    }
    void hand(double angle, double length, double width) {
      canvas.drawLine(
        center,
        center + Offset(math.sin(angle), -math.cos(angle)) * length,
        Paint()
          ..color = foreground
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    hand((time.hour % 12 + time.minute / 60) * math.pi / 6, radius * .44, 4);
    hand((time.minute + time.second / 60) * math.pi / 30, radius * .69, 2.5);
    canvas.drawCircle(center, 4, Paint()..color = foreground);
  }

  @override
  bool shouldRepaint(_ClockFace oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.foreground != foreground ||
      oldDelegate.muted != muted;
}
