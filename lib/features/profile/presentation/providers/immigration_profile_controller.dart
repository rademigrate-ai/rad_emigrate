import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/datasources/immigration_profile_local_datasource.dart';
import '../../data/repositories/immigration_profile_repository_impl.dart';
import '../../domain/curated_rules_gate.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/immigration_profile_validator.dart';
import '../../domain/pathway_assessment.dart';
import '../../domain/recommendation_engine.dart';
import '../../domain/repositories/immigration_profile_repository.dart';

/// No default eligibility claims without an approved evidence-backed package.
const curatedPathwayRules = <PathwayEligibilityRule>[];

final immigrationProfileRepositoryProvider =
    Provider<ImmigrationProfileRepository>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return ImmigrationProfileRepositoryImpl(
        local: ImmigrationProfileLocalDataSource(prefs),
        assessment: const PathwayAssessmentService(),
      );
    });

/// Package envelope for curated pathway eligibility rules with explicit editorial approval.
final defaultCuratedRulePackage = CuratedRulePackage(
  packageId: 'ca-de-curated-v1',
  rules: curatedPathwayRules,
  editorialApproved: false,
  approvedAt: null,
  approverLabel: null,
  notes: 'No approved rule and evidence package is configured.',
);

final curatedRulePackageProvider = Provider<CuratedRulePackage>(
  (ref) => defaultCuratedRulePackage,
);

final approvedPathwayRulesProvider = Provider<List<PathwayEligibilityRule>>((
  ref,
) {
  final package = ref.watch(curatedRulePackageProvider);
  return const CuratedRulesGate().loadApproved(package);
});

final recommendationReportProvider = Provider<RecommendationReport>((ref) {
  final profileState = ref.watch(immigrationProfileControllerProvider);
  final rules = ref.watch(approvedPathwayRulesProvider);
  return const RecommendationEngine().recommend(
    profile: profileState.profile,
    candidateProgramIds: const [
      'express-entry',
      'de-chancenkarte',
      'ca-startup',
    ],
    rules: rules,
  );
});

class ImmigrationProfileState {
  const ImmigrationProfileState({
    required this.profile,
    required this.validation,
    this.assessment,
    this.isLoading = false,
    this.isSaving = false,
    this.lastSaved,
    this.errorMessage,
  });

  final ImmigrationProfile profile;
  final ImmigrationProfileValidationResult validation;
  final PathwayAssessmentResult? assessment;
  final bool isLoading;
  final bool isSaving;
  final DateTime? lastSaved;
  final String? errorMessage;

  ImmigrationProfileState copyWith({
    ImmigrationProfile? profile,
    ImmigrationProfileValidationResult? validation,
    PathwayAssessmentResult? assessment,
    bool? isLoading,
    bool? isSaving,
    DateTime? lastSaved,
    String? errorMessage,
    bool clearAssessment = false,
    bool clearError = false,
  }) {
    return ImmigrationProfileState(
      profile: profile ?? this.profile,
      validation: validation ?? this.validation,
      assessment: clearAssessment ? null : (assessment ?? this.assessment),
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      lastSaved: lastSaved ?? this.lastSaved,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final immigrationProfileControllerProvider =
    StateNotifierProvider<
      ImmigrationProfileController,
      ImmigrationProfileState
    >((ref) {
      final repo = ref.watch(immigrationProfileRepositoryProvider);
      final approvedRules = ref.watch(approvedPathwayRulesProvider);
      final userId = ref.watch(authenticatedUserIdProvider) ?? 'guest';
      return ImmigrationProfileController(
        repo,
        userId,
        approvedRules: () => approvedRules,
        isCurrent: () =>
            (ref.read(authenticatedUserIdProvider) ?? 'guest') == userId,
      );
    });

class ImmigrationProfileController
    extends StateNotifier<ImmigrationProfileState> {
  ImmigrationProfileController(
    this._repository,
    this._userId, {
    bool Function()? isCurrent,
    List<PathwayEligibilityRule> Function()? approvedRules,
  }) : _isCurrent = isCurrent ?? (() => true),
       _approvedRules =
           approvedRules ??
           (() => const CuratedRulesGate().loadApproved(
             defaultCuratedRulePackage,
           )),
       super(
         ImmigrationProfileState(
           profile: const ImmigrationProfile(),
           validation: ImmigrationProfileValidator.validate(
             const ImmigrationProfile(),
           ),
           isLoading: true,
         ),
       ) {
    load();
  }

  final ImmigrationProfileRepository _repository;
  final String _userId;
  final List<PathwayEligibilityRule> Function() _approvedRules;
  final bool Function() _isCurrent;
  bool get _active => mounted && _isCurrent();

  Future<void> load() async {
    if (!_active) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final existing = await _repository.getImmigrationProfile(_userId);
      if (!_active) return;
      final profile = existing ?? const ImmigrationProfile();
      final validation = _repository.validate(profile);
      state = state.copyWith(
        profile: profile,
        validation: validation,
        isLoading: false,
      );
    } catch (e) {
      if (!_active) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void updateField(
    ImmigrationProfileField field,
    String? value, {
    List<String>? languageList,
  }) {
    if (!_active) return;
    final nextProfile = state.profile.provide(
      field,
      value: value,
      languageList: languageList,
    );
    final validation = _repository.validate(nextProfile);
    state = state.copyWith(
      profile: nextProfile,
      validation: validation,
      clearError: true,
    );
  }

  void toggleUnknown(ImmigrationProfileField field, bool isUnknown) {
    if (!_active) return;
    final nextProfile = isUnknown
        ? state.profile.markUnknown(field)
        : state.profile.provide(field, value: null);
    final validation = _repository.validate(nextProfile);
    state = state.copyWith(
      profile: nextProfile,
      validation: validation,
      clearError: true,
    );
  }

  Future<bool> saveDraft() async {
    if (!_active || state.isSaving) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final saved = await _repository.saveImmigrationProfile(
        _userId,
        state.profile,
      );
      if (!_active) return false;
      state = state.copyWith(
        profile: saved,
        validation: _repository.validate(saved),
        isSaving: false,
        lastSaved: DateTime.now(),
      );
      return true;
    } catch (e) {
      if (!_active) return false;
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      return false;
    }
  }

  void assessPathway(
    String programId, {
    List<PathwayEligibilityRule>? customRules,
  }) {
    if (!_active) return;
    final rules = customRules ?? _approvedRules();
    final assessment = _repository.assessPathway(
      profile: state.profile,
      programId: programId,
      rules: rules,
    );
    state = state.copyWith(assessment: assessment);
  }

  void clearAssessment() {
    if (!_active) return;
    state = state.copyWith(clearAssessment: true);
  }

  Future<void> clearDraft() async {
    if (!_active) return;
    await _repository.clearLocalDraft(_userId);
    if (!_active) return;
    state = state.copyWith(
      profile: const ImmigrationProfile(),
      validation: _repository.validate(const ImmigrationProfile()),
      clearAssessment: true,
      clearError: true,
    );
  }
}
