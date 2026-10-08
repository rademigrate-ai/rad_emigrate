import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/city.dart';

/// Interactive dark world map. Tapping resolves a coordinate via the
/// controller's nearest-city fallback (documented limitation when full
/// boundary polygons are not bundled).
class WorldMapPanel extends StatefulWidget {
  const WorldMapPanel({
    super.key,
    required this.cities,
    required this.selected,
    required this.onTapCoordinate,
    required this.onSelectCity,
  });

  final List<City> cities;
  final City? selected;
  final void Function(double lat, double lng) onTapCoordinate;
  final void Function(City city) onSelectCity;

  @override
  State<WorldMapPanel> createState() => _WorldMapPanelState();
}

class _WorldMapPanelState extends State<WorldMapPanel> {
  final MapController _controller = MapController();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: const LatLng(20, 20),
              initialZoom: 1.6,
              minZoom: 1.0,
              maxZoom: 8,
              backgroundColor: const Color(0xFF0A1018),
              onTap: (tapPos, latLng) {
                widget.onTapCoordinate(latLng.latitude, latLng.longitude);
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.rad.emigrate',
                retinaMode: true,
              ),
              MarkerLayer(
                markers: [
                  for (final city in widget.cities)
                    Marker(
                      point: city.latLng,
                      width: 28,
                      height: 28,
                      child: GestureDetector(
                        onTap: () => widget.onSelectCity(city),
                        child: _CityMarker(
                          selected: widget.selected?.id == city.id,
                        ),
                      ),
                    ),
                  if (widget.selected != null &&
                      !widget.cities.any((c) => c.id == widget.selected!.id))
                    Marker(
                      point: widget.selected!.latLng,
                      width: 32,
                      height: 32,
                      child: const _CityMarker(selected: true),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              children: [
                _MapBtn(
                  icon: Icons.add,
                  onTap: () => _controller.move(
                    _controller.camera.center,
                    _controller.camera.zoom + 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                _MapBtn(
                  icon: Icons.remove,
                  onTap: () => _controller.move(
                    _controller.camera.center,
                    _controller.camera.zoom - 0.6,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '© CARTO / OSM',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CityMarker extends StatelessWidget {
  const _CityMarker({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primaryRed : AppColors.primaryRed.withValues(alpha: 0.7),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withValues(alpha: selected ? 0.7 : 0.35),
            blurRadius: selected ? 14 : 8,
            spreadRadius: selected ? 2 : 0,
          ),
        ],
        border: Border.all(color: Colors.white, width: selected ? 2.5 : 1.5),
      ),
    );
  }
}

class _MapBtn extends StatelessWidget {
  const _MapBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A222D),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
