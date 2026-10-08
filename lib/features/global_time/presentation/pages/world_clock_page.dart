import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/rad_brand.dart';
import '../../domain/city.dart';
import '../../domain/geo_timezone_resolver.dart';
import '../../domain/timezone_engine.dart';
import '../providers/global_time_controller.dart';
import '../widgets/city_clock_card.dart';
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
  double _scrubHour = DateTime.now().hour + DateTime.now().minute / 60.0;

  @override
  void initState() {
    super.initState();
    TimezoneEngine.ensureInitialized();
    GeoTimezoneResolver.ensureReady();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
            label: lang == 'fa' ? 'افزودن' : 'Add',
            onPressed: () => ctrl.addFavorite(city),
          ),
        ),
      );
      return;
    }

    final message = result.status == GeoResolveStatus.unresolved
        ? (lang == 'fa'
              ? 'منطقه زمانی برای این نقطه یافت نشد (اقیانوس یا خارج از مرزها).'
              : 'No timezone for this point (ocean or outside land zones).')
        : (lang == 'fa'
              ? 'داده‌های مرز زمانی در دسترس نیست.'
              : 'Timezone boundary data unavailable.');

    final manual = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A222D),
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
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              Text(
                lang == 'fa'
                    ? 'انتخاب دستی منطقه زمانی'
                    : 'Select timezone manually',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final id in GeoTimezoneResolver.commonIanaIds)
                      ListTile(
                        title: Text(
                          id,
                          style: const TextStyle(color: Colors.white),
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
              label: lang == 'fa' ? 'افزودن' : 'Add',
              onPressed: () => ctrl.addFavorite(city),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(globalTimeControllerProvider);
    final ctrl = ref.read(globalTimeControllerProvider.notifier);
    final lang = Localizations.localeOf(context).languageCode;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final medium = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0B111A),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _HeroHeader(languageCode: lang)),
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 28 : 16,
                    vertical: 12,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: lang == 'fa'
                                ? 'جستجوی شهر، کشور یا منطقه زمانی…'
                                : 'Search city, country, or timezone…',
                            hintStyle: const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.white54,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF141C28),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (q) =>
                              ctrl.setSearchQuery(q, languageCode: lang),
                        ),
                        if (state.searchResults.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...state.searchResults
                              .take(6)
                              .map(
                                (c) => ListTile(
                                  dense: true,
                                  tileColor: const Color(0xFF141C28),
                                  title: Text(
                                    '${c.flagEmoji ?? ''} ${c.localizedName(lang)}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    c.timezone,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      color: AppColors.primaryRed,
                                    ),
                                    onPressed: () => ctrl.addFavorite(c),
                                  ),
                                  onTap: () => ctrl.selectCity(c),
                                ),
                              ),
                        ],
                        const SizedBox(height: 20),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: SizedBox(
                                  height: 360,
                                  child: WorldMapPanel(
                                    cities: state.favorites,
                                    selected: state.selectedCity,
                                    onTapCoordinate: (lat, lng) =>
                                        _onMapTap(lat, lng, lang),
                                    onSelectCity: ctrl.selectCity,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 4,
                                child: _CityGrid(
                                  cities: state.favorites,
                                  languageCode: lang,
                                  atUtc: state.scrubUtc,
                                  onRemove: ctrl.removeFavorite,
                                  onTap: ctrl.selectCity,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _CityGrid(
                            cities: state.favorites,
                            languageCode: lang,
                            atUtc: state.scrubUtc,
                            onRemove: ctrl.removeFavorite,
                            onTap: ctrl.selectCity,
                            columns: medium ? 2 : 1,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 280,
                            child: WorldMapPanel(
                              cities: state.favorites,
                              selected: state.selectedCity,
                              onTapCoordinate: (lat, lng) =>
                                  _onMapTap(lat, lng, lang),
                              onSelectCity: ctrl.selectCity,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        MeetingPlannerPanel(
                          cities: state.favorites,
                          languageCode: lang,
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141C28),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primaryRed.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang == 'fa'
                                    ? 'خط زمانی ۲۴ ساعته'
                                    : '24-Hour Timeline',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              TimelineScrubber(
                                selectedHour: _scrubHour,
                                onChanged: (h) {
                                  setState(() => _scrubHour = h);
                                  final now = DateTime.now().toUtc();
                                  final scrub = DateTime.utc(
                                    now.year,
                                    now.month,
                                    now.day,
                                    h.floor(),
                                    ((h % 1) * 60).round(),
                                  );
                                  ctrl.setScrubUtc(scrub);
                                },
                              ),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _scrubHour =
                                          DateTime.now().hour +
                                          DateTime.now().minute / 60.0;
                                    });
                                    ctrl.setScrubUtc(null);
                                  },
                                  child: Text(lang == 'fa' ? 'اکنون' : 'Now'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.languageCode});
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF121A28), Color(0xFF0B111A)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RadBrand(
              size: RadBrandSize.small,
              showInstituteName: false,
              darkSurface: true,
            ),
            const SizedBox(height: 16),
            Text(
              'RAD Global Time',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              languageCode == 'fa'
                  ? 'زمان جهان، هماهنگ با مسیر شما'
                  : 'World time, aligned with your journey',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              languageCode == 'fa'
                  ? 'ساعت شهرهای مهم، مقایسه زمان و برنامه‌ریزی جلسات بین‌المللی'
                  : 'Key city clocks, timezone comparison, and international meeting planning',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityGrid extends StatelessWidget {
  const _CityGrid({
    required this.cities,
    required this.languageCode,
    this.atUtc,
    this.onRemove,
    this.onTap,
    this.columns = 2,
  });

  final List<City> cities;
  final String languageCode;
  final DateTime? atUtc;
  final void Function(String id)? onRemove;
  final void Function(City city)? onTap;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemCount: cities.length,
      itemBuilder: (context, i) {
        final city = cities[i];
        return CityClockCard(
          city: city,
          languageCode: languageCode,
          atUtc: atUtc,
          onRemove: onRemove != null ? () => onRemove!(city.id) : null,
          onTap: onTap != null ? () => onTap!(city) : null,
        );
      },
    );
  }
}
