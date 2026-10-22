import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/fx_repository.dart';
import '../../domain/entities/fx_rate.dart';

final fxRepositoryProvider = Provider<FxRepository>((ref) {
  final supabaseService = ref.watch(supabaseClientServiceProvider);
  return SupabaseFxRepository(supabaseService);
});

/// Controls global currency display preference:
/// true => Display in Toman (IRR / 10)
/// false => Display in Rial (IRR)
final isTomanDisplayProvider = StateProvider<bool>((ref) => true);

/// Provides the current exchange rate quote for a base currency against IRR.
final fxRateQuoteProvider = FutureProvider.family<FxRateQuote, String>((
  ref,
  baseCurrency,
) async {
  final repository = ref.watch(fxRepositoryProvider);
  return repository.getQuote(base: baseCurrency, quote: 'IRR');
});
