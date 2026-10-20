import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/interview_repository.dart';
import '../../domain/entities/interview_slot.dart';

final interviewRepositoryProvider = Provider<InterviewRepository>((ref) {
  return SupabaseInterviewRepository(ref.watch(supabaseClientServiceProvider));
});

final availableInterviewSlotsProvider =
    FutureProvider.family<List<InterviewSlot>, String>((ref, locale) async {
      return ref
          .watch(interviewRepositoryProvider)
          .listAvailableSlots(locale: locale);
    });
