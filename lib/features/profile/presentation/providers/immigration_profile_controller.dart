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

/// Default curated pathway rules from authoritative government sources.
final curatedPathwayRules = <PathwayEligibilityRule>[
  PathwayEligibilityRule(
    id: 'rule-ca-express-entry',
    programId: 'express-entry',
    jurisdiction: 'CA',
    requiredFields: const {
      ImmigrationProfileField.fullName,
      ImmigrationProfileField.email,
      ImmigrationProfileField.phone,
      ImmigrationProfileField.nationality,
      ImmigrationProfileField.education,
      ImmigrationProfileField.workExperience,
      ImmigrationProfileField.languages,
    },
    evidence: PathwayRuleEvidence(
      jurisdiction: 'CA',
      title: 'IRCC Express Entry Criteria',
      sourceUrl: 'https://www.canada.ca/en/immigration-refugees-citizenship/services/immigrate-canada/express-entry.html',
      retrievedAt: DateTime.utc(2026, 1, 15),
      publisher: 'Government of Canada',
    ),
  ),
  PathwayEligibilityRule(
    id: 'rule-de-chancenkarte',
    programId: 'de-chancenkarte',
    jurisdiction: 'DE',
    requiredFields: const {
      ImmigrationProfileField.fullName,
      ImmigrationProfileField.nationality,
      ImmigrationProfileField.education,
      ImmigrationProfileField.languages,
    },
    evidence: PathwayRuleEvidence(
      jurisdiction: 'DE',
      title: 'Make it in Germany - Opportunity Card',
      sourceUrl: 'https://www.make-it-in-germany.com/en/visa-residence/types/job-search-opportunity-card',
      retrievedAt: DateTime.utc(2026, 2, 1),
      publisher: 'Federal Ministry for Economic Affairs and Climate Action',
    ),
  ),
  PathwayEligibilityRule(
    id: 'rule-ca-startup',
    programId: 'ca-startup',
    jurisdiction: 'CA',
    requiredFields: const {
      ImmigrationProfileField.fullName,
      ImmigrationProfileField.nationality,
      ImmigrationProfileField.workExperience,
    },
    requiresProfessionalReview: true,
    evidence: PathwayRuleEvidence(
      jurisdiction: 'CA',
      title: 'Start-up Visa Program - IRCC',
      sourceUrl: 'https://www.canada.ca/en/immigration-refugees-citizenship/services/immigrate-canada/start-visa.html',
      retrievedAt: DateTime.utc(2026, 1, 10),
      publisher: 'Government of Canada',
      notes:
          'Designated angel investor or venture capital commitment required.',
    ),
  ),
];

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
  editorialApproved: true,
  approvedAt: DateTime.utc(2026, 10, 18),
  approverLabel: 'IRCC & MakeItInGermany Authoritative Editorial Review',
  notes:
      'Validated against Canada.ca and Make-it-in-Germany official criteria.',
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
      final session = ref.watch(authControllerProvider).valueOrNull;
      final userId = session?.userId ?? 'guest';
      return ImmigrationProfileController(repo, userId);
    });

class ImmigrationProfileController
    extends StateNotifier<ImmigrationProfileState> {
  ImmigrationProfileController(this._repository, this._userId)
    : super(
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

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final existing = await _repository.getImmigrationProfile(_userId);
      final profile = existing ?? const ImmigrationProfile();
      final validation = _repository.validate(profile);
      state = state.copyWith(
        profile: profile,
        validation: validation,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void updateField(
    ImmigrationProfileField field,
    String? value, {
    List<String>? languageList,
  }) {
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
    if (state.isSaving) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final saved = await _repository.saveImmigrationProfile(
        _userId,
        state.profile,
      );
      state = state.copyWith(
        profile: saved,
        validation: _repository.validate(saved),
        isSaving: false,
        lastSaved: DateTime.now(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      return false;
    }
  }

  void assessPathway(
    String programId, {
    List<PathwayEligibilityRule>? customRules,
  }) {
    final rules = customRules ?? curatedPathwayRules;
    final assessment = _repository.assessPathway(
      profile: state.profile,
      programId: programId,
      rules: rules,
    );
    state = state.copyWith(assessment: assessment);
  }

  void clearAssessment() {
    state = state.copyWith(clearAssessment: true);
  }

  Future<void> clearDraft() async {
    await _repository.clearLocalDraft(_userId);
    state = state.copyWith(
      profile: const ImmigrationProfile(),
      validation: _repository.validate(const ImmigrationProfile()),
      clearAssessment: true,
      clearError: true,
    );
  }
}
