import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/theme/premium_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/city.dart';
import '../../domain/local_date_format.dart';
import '../../domain/solar_daylight.dart';
import '../../domain/timezone_engine.dart';
import 'global_time_labels.dart';

class GlobalTimeOverview extends StatefulWidget {
  const GlobalTimeOverview({
    super.key,
    required this.cities,
    required this.language,
    required this.instant,
    required this.onSelect,
    this.showMap = true,
  });
  final List<City> cities;
  final String language;
  final DateTime instant;
  final ValueChanged<City> onSelect;
  final bool showMap;
  @override
  State<GlobalTimeOverview> createState() => _GlobalTimeOverviewState();
}

class _GlobalTimeOverviewState extends State<GlobalTimeOverview> {
  static Future<List<List<Offset>>>? _land;
  late final Future<List<List<Offset>>> _geometry = _land ??= _loadLand();
  static Future<List<List<Offset>>> _loadLand() async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/images/world_land.geojson'),
    ) as Map<String, dynamic>;
    final rings = <List<Offset>>[];
    for (final feature in data['features'] as List) {
      final geometry = feature['geometry'];
      final polygons = geometry['type'] == 'Polygon'
          ? [geometry['coordinates']]
          : geometry['coordinates'] as List;
      for (final polygon in polygons) {
        rings.add([
          for (final p in polygon[0])
            Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ]);
      }
    }
    return rings;
  }

  @override
  Widget build(BuildContext context) {
    final labels = GlobalTimeLabels(widget.language);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.premium.border),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E2035), Color(0xFF070D19)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labels.title,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).worldTimeTagline,
              style: const TextStyle(color: Color(0xFFD7E2F1)),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).worldTimeDescription,
              style: const TextStyle(color: Color(0xFFACBCD1), fontSize: 12),
            ),
            if (widget.showMap)
              SizedBox(
                height: 190,
                child: FutureBuilder<List<List<Offset>>>(
                  future: _geometry,
                  builder: (context, snap) => LayoutBuilder(
                    builder: (context, box) => GestureDetector(
                      onTapUp: (tap) {
                        if (widget.cities.isEmpty) return;
                        final city = widget.cities.reduce(
                          (a, b) =>
                              (_WorldPainter.point(
                                            a.longitude,
                                            a.latitude,
                                            box.biggest,
                                          ) -
                                          tap.localPosition)
                                      .distance <
                                  (_WorldPainter.point(
                                            b.longitude,
                                            b.latitude,
                                            box.biggest,
                                          ) -
                                          tap.localPosition)
                                      .distance
                              ? a
                              : b,
                        );
                        if ((_WorldPainter.point(
                                      city.longitude,
                                      city.latitude,
                                      box.biggest,
                                    ) -
                                    tap.localPosition)
                                .distance <
                            28) {
                          widget.onSelect(city);
                        }
                      },
                      child: CustomPaint(
                        size: box.biggest,
                        painter: _WorldPainter(snap.data ?? [], widget.cities),
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.showMap)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final city in widget.cities)
                    ActionChip(
                      backgroundColor: const Color(0xFF162638),
                      side: const BorderSide(color: Color(0xFF34445A)),
                      onPressed: () => widget.onSelect(city),
                      label: Text(
                        '${city.localizedName(widget.language)}  ${formatLocalTime(tz.TZDateTime.from(widget.instant, TimezoneEngine.locationOf(city.timezone)))}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _WorldPainter extends CustomPainter {
  const _WorldPainter(this.land, this.cities);
  final List<List<Offset>> land;
  final List<City> cities;
  static Offset point(double lon, double lat, Size size) =>
      Offset((lon + 180) / 360 * size.width, (85 - lat) / 170 * size.height);
  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = const Color(0xFF233B54)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    for (var lon = -180; lon <= 180; lon += 30) {
      final x = point(lon.toDouble(), 0, size).dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), border);
    }
    for (var lat = -60; lat <= 60; lat += 30) {
      final y = point(0, lat.toDouble(), size).dy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), border);
    }
    for (final ring in land) {
      final path = Path();
      for (var i = 0; i < ring.length; i++) {
        final p = point(ring[i].dx, ring[i].dy, size);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = const Color(0xFF294863));
      canvas.drawPath(path, border);
    }
    if (cities.isNotEmpty) {
      final origin = point(cities.first.longitude, cities.first.latitude, size);
      for (final city in cities.skip(1)) {
        final end = point(city.longitude, city.latitude, size);
        final path = Path()
          ..moveTo(origin.dx, origin.dy)
          ..quadraticBezierTo(
            (origin.dx + end.dx) / 2,
            math.min(origin.dy, end.dy) - 45,
            end.dx,
            end.dy,
          );
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xAAFF304B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
    for (final city in cities) {
      final p = point(city.longitude, city.latitude, size);
      canvas.drawCircle(
        p,
        11,
        Paint()
          ..color = const Color(0x55FF304B)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(p, 3, Paint()..color = const Color(0xFFFF4760));
      canvas.drawCircle(p, 1.4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_WorldPainter old) =>
      old.land != land || old.cities != cities;
}

class GlobalTimeTimeline extends StatelessWidget {
  const GlobalTimeTimeline({
    super.key,
    required this.cities,
    required this.language,
    required this.instant,
    required this.selected,
    required this.onChanged,
    required this.onLive,
  });
  final List<City> cities;
  final String language;
  final DateTime instant;
  final double? selected;
  final ValueChanged<double> onChanged;
  final VoidCallback onLive;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), labels = GlobalTimeLabels(language);
    final start = DateTime.utc(instant.year, instant.month, instant.day);
    final hour = selected ?? instant.hour + instant.minute / 60;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.premium.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.premium.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: Color(0xFFFF7685)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${l.timeline24Hours} (UTC)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(onPressed: onLive, child: Text(l.timeNow)),
            ],
          ),
          Text(labels.solar, style: Theme.of(context).textTheme.bodySmall),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Slider(
              value: hour.clamp(0, 24),
              min: 0,
              max: 24,
              divisions: 48,
              label:
                  '${(hour * 60).round() ~/ 60}:${((hour * 60).round() % 60).toString().padLeft(2, '0')} UTC',
              semanticFormatterCallback: (v) => '${v.toStringAsFixed(1)} UTC',
              onChanged: onChanged,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                children: [
                  for (final city in cities)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              city.localizedName(language),
                              maxLines: 2,
                            ),
                          ),
                          for (var h = 0; h < 24; h++)
                            Builder(
                              builder: (context) {
                                final utc = start.add(Duration(hours: h));
                                final local = tz.TZDateTime.from(
                                  utc,
                                  TimezoneEngine.locationOf(city.timezone),
                                );
                                final day = SolarDaylight.at(city, utc);
                                return Tooltip(
                                  message:
                                      '${city.localizedName(language)} ${formatLocalDate(local, language)} ${formatLocalTime(local)}',
                                  child: Container(
                                    width: 26,
                                    height: 28,
                                    alignment: Alignment.center,
                                    margin: const EdgeInsets.only(right: 1),
                                    decoration: BoxDecoration(
                                      color: day
                                          ? const Color(0xFFB8CBDC)
                                          : const Color(0xFF1B2B43),
                                      border: h == hour.floor()
                                          ? Border.all(
                                              color: const Color(0xFFFF304B),
                                              width: 2,
                                            )
                                          : null,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      '${local.hour}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: day
                                            ? const Color(0xFF101B2A)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
