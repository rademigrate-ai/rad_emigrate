import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/visa_repository.dart';
import '../../domain/entities/visa_entities.dart';

final visaRepositoryProvider = Provider<VisaRepository>((ref) {
  return VisaRepository(ref.watch(supabaseClientServiceProvider));
});

final visaCatalogProvider = FutureProvider.family<VisaCatalog, String>((
  ref,
  locale,
) {
  return ref.watch(visaRepositoryProvider).loadCatalog(locale: locale);
});
