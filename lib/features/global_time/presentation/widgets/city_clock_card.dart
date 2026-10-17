import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../l10n/app_localizations.dart';
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
                      context.premium.surface.withValues(alpha: .86),
                      context.premium.surface,
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
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: context.premium.text,
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
                                ? context.premium.warning
                                : context.premium.information,
                          ),
                          if (onRemove != null) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              color: context.premium.mutedText,
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
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: context.premium.text,
                              fontWeight: FontWeight.w800,
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
                            ?.copyWith(color: context.premium.mutedText),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        offset,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.premium.accentForeground,
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
    'AU': 'assets/images/destinations/au.jpg',
    'CA': 'assets/images/destinations/ca.jpg',
    'DE': 'assets/images/destinations/de.jpg',
    'FR': 'assets/images/destinations/fr.jpg',
    'GB': 'assets/images/destinations/gb.jpg',
    'JP': 'assets/images/destinations/jp.jpg',
    'US': 'assets/images/destinations/us.jpg',
  };

  @override
  Widget build(BuildContext context) {
    final url = _photos[city.countryCode.toUpperCase()];
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
