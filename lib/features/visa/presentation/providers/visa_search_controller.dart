import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/visa_search_repository.dart';
import '../../domain/entities/search_entities.dart';

class VisaSearchState {
  final String query;
  final String? countryFilter;
  final String? categoryFilter;
  final AsyncValue<SmartSearchResult> result;

  const VisaSearchState({
    required this.query,
    this.countryFilter,
    this.categoryFilter,
    required this.result,
  });

  VisaSearchState copyWith({
    String? query,
    String? countryFilter,
    String? categoryFilter,
    bool clearCountry = false,
    bool clearCategory = false,
    AsyncValue<SmartSearchResult>? result,
  }) {
    return VisaSearchState(
      query: query ?? this.query,
      countryFilter: clearCountry
          ? null
          : (countryFilter ?? this.countryFilter),
      categoryFilter: clearCategory
          ? null
          : (categoryFilter ?? this.categoryFilter),
      result: result ?? this.result,
    );
  }
}

class VisaSearchNotifier extends StateNotifier<VisaSearchState> {
  final VisaSearchRepository _repository;
  String _locale = 'fa';
  int _generation = 0;

  VisaSearchNotifier(this._repository)
    : super(
        VisaSearchState(
          query: '',
          result: AsyncValue.data(SmartSearchResult.empty('')),
        ),
      );

  Future<void> search(String query, {String? locale}) async {
    _locale = locale ?? _locale;
    final generation = ++_generation;
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        query: '',
        result: AsyncValue.data(SmartSearchResult.empty('')),
      );
      return;
    }

    state = state.copyWith(query: trimmed, result: const AsyncValue.loading());

    try {
      final res = await _repository.search(
        query: trimmed,
        locale: _locale,
        countryFilter: state.countryFilter,
        categoryFilter: state.categoryFilter,
      );
      if (!mounted || generation != _generation) return;
      state = state.copyWith(result: AsyncValue.data(res));
    } catch (e, st) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(result: AsyncValue.error(e, st));
    }
  }

  void setCountryFilter(String? countryCode) {
    if (countryCode == null || countryCode == 'all') {
      state = state.copyWith(clearCountry: true);
    } else {
      state = state.copyWith(countryFilter: countryCode);
    }
    if (state.query.isNotEmpty) {
      search(state.query);
    }
  }

  void setCategoryFilter(String? category) {
    if (category == null || category == 'all') {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(categoryFilter: category);
    }
    if (state.query.isNotEmpty) {
      search(state.query);
    }
  }

  void clear() {
    state = VisaSearchState(
      query: '',
      result: AsyncValue.data(SmartSearchResult.empty('')),
    );
  }
}

final visaSearchControllerProvider =
    StateNotifierProvider<VisaSearchNotifier, VisaSearchState>((ref) {
      final repo = ref.watch(visaSearchRepositoryProvider);
      return VisaSearchNotifier(repo);
    });
