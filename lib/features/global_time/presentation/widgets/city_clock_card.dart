import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/city.dart';
import '../../domain/local_date_format.dart';
import '../../domain/timezone_engine.dart';
import '../../domain/solar_daylight.dart';

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

    final isDay = SolarDaylight.at(city, atUtc ?? DateTime.now().toUtc());
    final offset = TimezoneEngine.offsetLabel(city.timezone, at: atUtc);
    final timeStr = formatLocalTime(now);
    final dateStr = formatLocalDate(now, languageCode);
    final name = city.localizedName(languageCode);

    return AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.standard),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        color: context.premium.surface,
        border: Border.all(color: context.premium.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _CityPhotography(city: city),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .10),
                      Colors.black.withValues(alpha: .86),
                    ],
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadii.lg),
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
                            SizedBox(width: compact ? 5 : 8),
                          ],
                          Expanded(
                            child: Text(
                              name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: compact ? 14 : null,
                                  ),
                              maxLines: compact ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            isDay
                                ? Icons.wb_sunny_rounded
                                : Icons.nights_stay_rounded,
                            size: compact ? 16 : 18,
                            color: isDay
                                ? context.premium.warning
                                : context.premium.information,
                          ),
                          if (onRemove != null) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              color: const Color(0xFFE2E8F0),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              onPressed: onRemove,
                              tooltip: AppLocalizations.of(context).delete,
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: compact ? 8 : 12),
                      Text(
                        timeStr,
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: compact ? 28 : null,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: const Color(0xFFE2E8F0)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        offset,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFFFA1AC),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityPhotography extends StatelessWidget {
  const _CityPhotography({required this.city});

  final City city;

  static const _photos = <String, String>{
    'sydney': 'assets/images/destinations/au.jpg',
    'tehran': 'assets/images/destinations/tehran.jpg',
    'dubai': 'assets/images/destinations/ae.jpg',
    'berlin': 'assets/images/destinations/berlin.jpg',
    'toronto': 'assets/images/destinations/ca.jpg',
    'paris': 'assets/images/destinations/fr.jpg',
    'london': 'assets/images/destinations/gb.jpg',
    'tokyo': 'assets/images/destinations/jp.jpg',
    'new_york': 'assets/images/destinations/us.jpg',
  };

  @override
  Widget build(BuildContext context) {
    final url = _photos[city.id];
    if (url == null) return const _CityPhotoFallback();
    return Image.asset(
      url,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const _CityPhotoFallback(),
    );
  }
}

class _CityPhotoFallback extends StatelessWidget {
  const _CityPhotoFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.premium.surfaceElevated,
      child: Align(
        alignment: const Alignment(.78, -.7),
        child: Icon(
          Icons.location_city_outlined,
          color: context.premium.accent.withValues(alpha: .12),
          size: 64,
        ),
      ),
    );
  }
}
