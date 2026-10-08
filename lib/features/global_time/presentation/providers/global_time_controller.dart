import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/favorites_repository.dart';
import '../../domain/city.dart';
import '../../domain/city_catalog.dart';
import '../../domain/geo_timezone_resolver.dart';
import '../../domain/timezone_engine.dart';

class GlobalTimeState {
  const GlobalTimeState({
    this.favorites = const [],
    this.searchQuery = '',
    this.searchResults = const [],
    this.selectedCity,
    this.scrubUtc,
    this.isLoading = true,
    this.lastResolve,
  });

  final List<City> favorites;
  final String searchQuery;
  final List<City> searchResults;
  final City? selectedCity;
  final DateTime? scrubUtc;
  final bool isLoading;
  final GeoResolveResult? lastResolve;

  GlobalTimeState copyWith({
    List<City>? favorites,
    String? searchQuery,
    List<City>? searchResults,
    City? selectedCity,
    DateTime? scrubUtc,
    bool clearScrub = false,
    bool clearSelected = false,
    bool? isLoading,
    GeoResolveResult? lastResolve,
    bool clearResolve = false,
  }) {
    return GlobalTimeState(
      favorites: favorites ?? this.favorites,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      selectedCity: clearSelected ? null : (selectedCity ?? this.selectedCity),
      scrubUtc: clearScrub ? null : (scrubUtc ?? this.scrubUtc),
      isLoading: isLoading ?? this.isLoading,
      lastResolve: clearResolve ? null : (lastResolve ?? this.lastResolve),
    );
  }
}

class GlobalTimeController extends StateNotifier<GlobalTimeState> {
  GlobalTimeController(this._ref) : super(const GlobalTimeState()) {
    _init();
  }

  final Ref _ref;
  Timer? _ticker;

  Future<void> _init() async {
    await TimezoneEngine.ensureInitialized();
    await GeoTimezoneResolver.ensureReady();
    final repo = _ref.read(favoritesRepositoryProvider);
    final favs = repo?.load() ?? List<City>.from(CityCatalog.defaults);
    state = state.copyWith(favorites: favs, isLoading: false);
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.scrubUtc == null) {
        state = state.copyWith();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void setSearchQuery(String query, {String languageCode = 'en'}) {
    final results = CityCatalog.search(query, languageCode: languageCode);
    state = state.copyWith(searchQuery: query, searchResults: results);
  }

  Future<void> addFavorite(City city) async {
    final repo = _ref.read(favoritesRepositoryProvider);
    if (repo == null) {
      if (state.favorites.any((c) => c.id == city.id || c.timezone == city.timezone && (c.latitude - city.latitude).abs() < 0.01)) {
        return;
      }
      state = state.copyWith(favorites: [...state.favorites, city]);
      return;
    }
    final next = await repo.add(city);
    state = state.copyWith(favorites: next);
  }

  Future<void> removeFavorite(String cityId) async {
    final repo = _ref.read(favoritesRepositoryProvider);
    if (repo == null) {
      state = state.copyWith(
        favorites: state.favorites.where((c) => c.id != cityId).toList(),
      );
      return;
    }
    final next = await repo.remove(cityId);
    state = state.copyWith(favorites: next);
  }

  Future<void> restoreDefaults() async {
    final repo = _ref.read(favoritesRepositoryProvider);
    final next = repo != null
        ? await repo.restoreDefaults()
        : List<City>.from(CityCatalog.defaults);
    state = state.copyWith(favorites: next);
  }

  void selectCity(City? city) {
    state = state.copyWith(
      selectedCity: city,
      clearSelected: city == null,
    );
  }

  void setScrubUtc(DateTime? utc) {
    state = state.copyWith(
      scrubUtc: utc,
      clearScrub: utc == null,
    );
  }

  /// Map tap: genuine boundary lookup. Never assigns a wrong city timezone
  /// silently — unresolved/unavailable surfaces in [lastResolve].
  Future<GeoResolveResult> resolveCoordinate(
    double latitude,
    double longitude,
  ) async {
    final result = await GeoTimezoneResolver.resolve(
      latitude: latitude,
      longitude: longitude,
    );
    final city = result.toCity();
    state = state.copyWith(
      lastResolve: result,
      selectedCity: city,
      clearSelected: city == null,
    );
    return result;
  }

  void applyManualTimezone({
    required double latitude,
    required double longitude,
    required String ianaId,
  }) {
    final city = GeoTimezoneResolver.cityWithManualTimezone(
      latitude: latitude,
      longitude: longitude,
      ianaId: ianaId,
    );
    state = state.copyWith(
      selectedCity: city,
      lastResolve: GeoResolveResult(
        status: GeoResolveStatus.resolved,
        ianaId: ianaId,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }
}

final globalTimeControllerProvider =
    StateNotifierProvider<GlobalTimeController, GlobalTimeState>((ref) {
  return GlobalTimeController(ref);
});
