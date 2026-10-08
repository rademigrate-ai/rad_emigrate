import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/favorites_repository.dart';
import '../../domain/city.dart';
import '../../domain/city_catalog.dart';
import '../../domain/timezone_engine.dart';

class GlobalTimeState {
  const GlobalTimeState({
    this.favorites = const [],
    this.searchQuery = '',
    this.searchResults = const [],
    this.selectedCity,
    this.scrubUtc,
    this.isLoading = true,
  });

  final List<City> favorites;
  final String searchQuery;
  final List<City> searchResults;
  final City? selectedCity;
  /// When non-null, clocks display this instant instead of wall clock.
  final DateTime? scrubUtc;
  final bool isLoading;

  GlobalTimeState copyWith({
    List<City>? favorites,
    String? searchQuery,
    List<City>? searchResults,
    City? selectedCity,
    DateTime? scrubUtc,
    bool clearScrub = false,
    bool clearSelected = false,
    bool? isLoading,
  }) {
    return GlobalTimeState(
      favorites: favorites ?? this.favorites,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      selectedCity: clearSelected ? null : (selectedCity ?? this.selectedCity),
      scrubUtc: clearScrub ? null : (scrubUtc ?? this.scrubUtc),
      isLoading: isLoading ?? this.isLoading,
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
    final repo = _ref.read(favoritesRepositoryProvider);
    final favs = repo?.load() ?? List<City>.from(CityCatalog.defaults);
    state = state.copyWith(favorites: favs, isLoading: false);
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      // Trigger rebuilds for live clocks when not scrubbing.
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
      if (state.favorites.any((c) => c.id == city.id)) return;
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

  /// Resolve a map tap to a city (nearest catalog entry) and select it.
  /// True boundary-based lookup is preferred when available; this is the
  /// documented offline fallback.
  City resolveCoordinate(double latitude, double longitude) {
    final city = CityCatalog.nearest(latitude, longitude);
    // Create a transient selection reflecting the tapped coordinates while
    // preserving the resolved timezone of the nearest known city.
    final resolved = city.copyWith(
      id: 'map_${latitude.toStringAsFixed(3)}_${longitude.toStringAsFixed(3)}',
      nameEn: city.nameEn,
      nameFa: city.nameFa,
      latitude: latitude,
      longitude: longitude,
    );
    selectCity(resolved);
    return resolved;
  }
}

final globalTimeControllerProvider =
    StateNotifierProvider<GlobalTimeController, GlobalTimeState>((ref) {
  return GlobalTimeController(ref);
});
