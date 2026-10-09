import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/city.dart';

/// Interactive world map. Uses free Esri Canvas tiles (no API key).
/// Tile style follows the active app theme.
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A1018) : const Color(0xFFE8EEF4);
    // Free Esri Canvas tiles — no API key, no watermark.
    // Note: Esri uses {z}/{y}/{x} order (not z/x/y).
    final tileUrl = isDark
        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}'
        : 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}';

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
              backgroundColor: bg,
              onTap: (tapPos, latLng) {
                widget.onTapCoordinate(latLng.latitude, latLng.longitude);
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.rad.emigrate',
                errorTileCallback: (tile, error, stackTrace) {},
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
                ],
              ),
            ],
          ),
          Positioned(
            right: 12,
            top: 12,
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
                color: theme.colorScheme.surface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Text(
                '© Esri',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
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
        color: selected
            ? AppColors.primaryRed
            : AppColors.primaryRed.withValues(alpha: 0.7),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withValues(
              alpha: selected ? 0.7 : 0.35,
            ),
            blurRadius: selected ? 14 : 8,
            spreadRadius: selected ? 2 : 0,
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.onPrimary,
          width: selected ? 2.5 : 1.5,
        ),
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
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: theme.colorScheme.onSurface, size: 18),
        ),
      ),
    );
  }
}
