import '../../../../core/widgets/app_back_button.dart';
import '../widgets/city_clock_grid.dart';
import '../widgets/global_time_labels.dart';
import '../widgets/global_time_overview.dart';
import '../../domain/city_catalog.dart';
import '../../../../l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../domain/city.dart';
import '../../domain/geo_timezone_resolver.dart';
import '../providers/global_time_controller.dart';
import '../widgets/reference_city_clock.dart';
import '../../../../core/widgets/app_card.dart';
import '../widgets/meeting_planner_panel.dart';
import '../widgets/world_map_panel.dart';

class WorldClockPage extends ConsumerStatefulWidget {
  const WorldClockPage({super.key});

  @override
  ConsumerState<WorldClockPage> createState() => _WorldClockPageState();
}

class _WorldClockPageState extends ConsumerState<WorldClockPage> {
  bool _showOverviewMap = false;
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
    final labels = GlobalTimeLabels(lang);
    final now = DateTime.now().toUtc();
    final instant = state.scrubUtc ?? now;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/dashboard'),
        title: Text(labels.title),
      ),
      body: PremiumCanvas(
        child: state.isLoading
            ? LoadingState.section(
                message: l10n.preparingWorldClocks,
                dark: context.premium.isDark,
              )
            : state.timezoneUnavailable
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(labels.timezoneError, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: ctrl.retryInitialization,
                      child: Text(labels.retry),
                    ),
                  ],
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        decoration: InputDecoration(
                          hintText: l10n.searchWorldClocks,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: l10n.addCity,
                            icon: const Icon(Icons.add),
                            onPressed: () => _searchFocus.requestFocus(),
                          ),
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
                              icon: Icon(
                                state.favorites.contains(city)
                                    ? Icons.check_circle
                                    : Icons.add_circle_outline,
                              ),
                              onPressed: state.favorites.contains(city)
                                  ? null
                                  : () async {
                                      await ctrl.addFavorite(city);
                                      if (mounted) {
                                        _searchCtrl.clear();
                                        ctrl.setSearchQuery('');
                                        _searchFocus.unfocus();
                                      }
                                    },
                            ),
                            onTap: () => _openCity(city),
                          ),
                      ],
                      const SizedBox(height: 16),
                      GlobalTimeOverview(
                        cities: state.favorites,
                        language: lang,
                        instant: instant,
                        onSelect: _openCity,
                        showMap: wide || _showOverviewMap,
                      ),
                      if (!wide) ...[
                        const SizedBox(height: 12),
                        SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(
                              value: false,
                              label: Text(labels.clocks),
                              icon: const Icon(Icons.schedule),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text(labels.map),
                              icon: const Icon(Icons.public),
                            ),
                          ],
                          selected: {_showOverviewMap},
                          onSelectionChanged: (v) =>
                              setState(() => _showOverviewMap = v.single),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              labels.clocks,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _searchFocus.requestFocus(),
                            icon: const Icon(Icons.add),
                            label: Text(l10n.addCity),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (state.favorites.isEmpty) Text(l10n.noWorldCities),
                      CityClockGrid(
                        cities: state.favorites,
                        languageCode: lang,
                        atUtc: instant,
                        onSelect: _openCity,
                        onRemove: ctrl.removeFavorite,
                      ),
                      const SizedBox(height: 20),
                      MeetingPlannerPanel(
                        cities: state.favorites,
                        languageCode: lang,
                      ),
                      const SizedBox(height: 20),
                      GlobalTimeTimeline(
                        cities: state.favorites,
                        language: lang,
                        instant: now,
                        selected: state.scrubUtc == null ? null : _scrubHour,
                        onChanged: (h) {
                          setState(() => _scrubHour = h);
                          ctrl.setScrubUtc(
                            DateTime.utc(
                              now.year,
                              now.month,
                              now.day,
                            ).add(Duration(minutes: (h * 60).round())),
                          );
                        },
                        onLive: () => ctrl.setScrubUtc(null),
                      ),
                      const SizedBox(height: 20),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labels.favorites,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final city in state.favorites)
                                  InputChip(
                                    label: Text(
                                      '${city.flagEmoji ?? ''} ${city.localizedName(lang)}',
                                    ),
                                    onPressed: () => _openCity(city),
                                    onDeleted: () =>
                                        ctrl.removeFavorite(city.id),
                                    deleteButtonTooltipMessage: labels.remove,
                                  ),
                                ActionChip(
                                  avatar: const Icon(Icons.add, size: 18),
                                  label: Text(l10n.addCity),
                                  onPressed: () => _showCityPicker(lang),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: ExpansionTile(
                          title: Text(labels.map),
                          leading: const Icon(Icons.public),
                          children: [
                            SizedBox(
                              height: 320,
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
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _showCityPicker(String lang) async {
    final ctrl = ref.read(globalTimeControllerProvider.notifier);
    final city = await showModalBottomSheet<City>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .65,
          child: ListView(
            children: [
              for (final c in CityCatalog.all)
                ListTile(
                  title: Text('${c.flagEmoji ?? ''} ${c.localizedName(lang)}'),
                  subtitle: Text(c.timezone),
                  onTap: () => Navigator.pop(ctx, c),
                ),
            ],
          ),
        ),
      ),
    );
    if (city != null && mounted) await ctrl.addFavorite(city);
  }
}
