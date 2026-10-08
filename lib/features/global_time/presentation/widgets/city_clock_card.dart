import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/constants/app_colors.dart';
import '../../domain/city.dart';
import '../../domain/local_date_format.dart';
import '../../domain/timezone_engine.dart';

class CityClockCard extends StatelessWidget {
  const CityClockCard({
    super.key,
    required this.city,
    required this.languageCode,
    this.atUtc,
    this.onRemove,
    this.onTap,
    this.compact = false,
  });

  final City city;
  final String languageCode;
  final DateTime? atUtc;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final now = atUtc != null
        ? tz.TZDateTime.from(
            atUtc!.toUtc(),
            TimezoneEngine.locationOf(city.timezone),
          )
        : TimezoneEngine.nowInCity(city);

    final isDay = TimezoneEngine.isDaytime(city.timezone, at: atUtc);
    final offset = TimezoneEngine.offsetLabel(city.timezone, at: atUtc);
    final timeStr = formatLocalTime(now);
    final dateStr = formatLocalDate(now, languageCode);
    final name = city.localizedName(languageCode);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDay
              ? const [Color(0xFF1E3A5F), Color(0xFF0F1C2E)]
              : const [Color(0xFF0A0F18), Color(0xFF121A28)],
        ),
        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (city.flagEmoji != null) ...[
                      Text(
                        city.flagEmoji!,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      isDay
                          ? Icons.wb_sunny_rounded
                          : Icons.nights_stay_rounded,
                      size: 18,
                      color: isDay
                          ? const Color(0xFFFFC857)
                          : const Color(0xFF8BA3C7),
                    ),
                    if (onRemove != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        color: Colors.white54,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: onRemove,
                        tooltip: 'Remove',
                      ),
                    ],
                  ],
                ),
                SizedBox(height: compact ? 8 : 12),
                Text(
                  timeStr,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  offset,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryRed.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
