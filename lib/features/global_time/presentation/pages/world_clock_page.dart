import '../../../../l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../domain/city.dart';
import '../../domain/geo_timezone_resolver.dart';
import '../providers/global_time_controller.dart';
import '../widgets/reference_city_clock.dart';
import '../../../../core/widgets/app_card.dart';
import '../widgets/meeting_planner_panel.dart';
import '../widgets/timeline_scrubber.dart';
import '../widgets/world_map_panel.dart';

class WorldClockPage extends ConsumerStatefulWidget {
  const WorldClockPage({super.key});

  @override
  ConsumerState<WorldClockPage> createState() => _WorldClockPageState();
}

class _WorldClockPageState extends ConsumerState<WorldClockPage> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  double _scrubHour = DateTime.now().hour + DateTime.now().minute / 60.0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _onMapTap(double lat, double lng, String lang) async {
    final ctrl = ref.read(globalTimeControllerProvider.notifier);
    final result = await ctrl.resolveCoordinate(lat, lng);
    if (!mounted) return;

    if (result.isResolved) {
      final city = result.toCity()!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang == 'fa'
                ? 'منطقه زمانی: ${result.ianaId}'
                : 'Timezone: ${result.ianaId}',
          ),
          action: SnackBarAction(
            label: AppLocalizations.of(context).addCity,
            onPressed: () => ctrl.addFavorite(city),
          ),
        ),
      );
      return;
    }

    final message = result.status == GeoResolveStatus.unresolved
        ? (AppLocalizations.of(context).timezonePointUnresolved)
        : (AppLocalizations.of(context).timezoneDataUnavailable);

    final manual = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.premium.surface,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  message,
                  style: TextStyle(color: context.premium.mutedText),
                ),
              ),
              Text(
                AppLocalizations.of(context).selectTimezoneManually,
                style: TextStyle(
                  color: context.premium.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final id in GeoTimezoneResolver.commonIanaIds)
                      ListTile(
                        title: Text(
                          id,
                          style: TextStyle(color: context.premium.text),
                        ),
                        onTap: () => Navigator.pop(ctx, id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (manual != null && mounted) {
      ctrl.applyManualTimezone(latitude: lat, longitude: lng, ianaId: manual);
      final city = ref.read(globalTimeControllerProvider).selectedCity;
      if (city != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang == 'fa' ? 'انتخاب دستی: $manual' : 'Manual: $manual',
            ),
            action: SnackBarAction(
              label: AppLocalizations.of(context).addCity,
              onPressed: () => ctrl.addFavorite(city),
            ),
          ),
        );
      }
    }
  }

  void _openCity(City city) {
    ref.read(globalTimeControllerProvider.notifier).selectCity(city);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .90,
        maxWidth: 560,
      ),
      builder: (_) => ReferenceCityDetail(city: city),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(globalTimeControllerProvider);
    final ctrl = ref.read(globalTimeControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.worldTimeTitle)),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addCity,
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        onPressed: () {
          ctrl.setSearchQuery(_searchCtrl.text, languageCode: lang);
          _searchFocus.requestFocus();
        },
        child: const Icon(Icons.add),
      ),
      body: PremiumCanvas(
        child: state.isLoading
            ? LoadingState.section(
                message: l10n.preparingWorldClocks,
                dark: context.premium.isDark,
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        decoration: InputDecoration(
                          hintText: l10n.searchWorldClocks,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                        ),
                        onChanged: (q) =>
                            ctrl.setSearchQuery(q, languageCode: lang),
                      ),
                      if (state.searchResults.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final city in state.searchResults.take(6))
                          ListTile(
                            title: Text(
                              '${city.flagEmoji ?? ''} ${city.localizedName(lang)}',
                            ),
                            subtitle: Text(city.timezone),
                            trailing: IconButton(
                              tooltip: l10n.addCity,
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => ctrl.addFavorite(city),
                            ),
                            onTap: () => _openCity(city),
                          ),
                      ],
                      const SizedBox(height: 16),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  for (final city in state.favorites)
                                    ReferenceCityRow(
                                      city: city,
                                      languageCode: lang,
                                      atUtc: state.scrubUtc,
                                      onTap: () => _openCity(city),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: SizedBox(
                                height: 370,
                                child: WorldMapPanel(
                                  cities: state.favorites,
                                  selected: state.selectedCity,
                                  onTapCoordinate: (lat, lng) =>
                                      _onMapTap(lat, lng, lang),
                                  onSelectCity: _openCity,
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        for (final city in state.favorites)
                          ReferenceCityRow(
                            city: city,
                            languageCode: lang,
                            atUtc: state.scrubUtc,
                            onTap: () => _openCity(city),
                          ),
                        const SizedBox(height: 12),
                        AppCard(
                          padding: EdgeInsets.zero,
                          child: ExpansionTile(
                            title: Text(l10n.worldTimeTagline),
                            leading: const Icon(Icons.public_outlined),
                            children: [
                              SizedBox(
                                height: 280,
                                child: WorldMapPanel(
                                  cities: state.favorites,
                                  selected: state.selectedCity,
                                  onTapCoordinate: (lat, lng) =>
                                      _onMapTap(lat, lng, lang),
                                  onSelectCity: _openCity,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: ExpansionTile(
                          title: Text(l10n.timeline24Hours),
                          leading: const Icon(Icons.schedule_outlined),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  MeetingPlannerPanel(
                                    cities: state.favorites,
                                    languageCode: lang,
                                  ),
                                  const SizedBox(height: 20),
                                  TimelineScrubber(
                                    selectedHour: _scrubHour,
                                    onChanged: (h) {
                                      setState(() => _scrubHour = h);
                                      final now = DateTime.now().toUtc();
                                      ctrl.setScrubUtc(
                                        DateTime.utc(
                                          now.year,
                                          now.month,
                                          now.day,
                                          h.floor(),
                                          ((h % 1) * 60).round(),
                                        ),
                                      );
                                    },
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(
                                        () => _scrubHour =
                                            DateTime.now().hour +
                                            DateTime.now().minute / 60.0,
                                      );
                                      ctrl.setScrubUtc(null);
                                    },
                                    child: Text(l10n.timeNow),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
