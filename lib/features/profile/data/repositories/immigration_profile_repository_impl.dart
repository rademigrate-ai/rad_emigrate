import '../../domain/entities/profile_entity.dart';
import '../../domain/immigration_profile_validator.dart';
import '../../domain/pathway_assessment.dart';
import '../../domain/repositories/immigration_profile_repository.dart';
import '../datasources/immigration_profile_local_datasource.dart';

/// Local-first immigration profile repository.
/// Ownership is enforced by requiring [userId] on every call; remote
/// Supabase RLS remains the production boundary (not simulated here).
class ImmigrationProfileRepositoryImpl implements ImmigrationProfileRepository {
  ImmigrationProfileRepositoryImpl({
    required this.local,
    this.assessment = const PathwayAssessmentService(),
  });

  final ImmigrationProfileLocalDataSource local;
  final PathwayAssessmentService assessment;

  @override
  Future<ImmigrationProfile?> getImmigrationProfile(String userId) {
    return local.read(userId);
  }

  @override
  Future<ImmigrationProfile> saveImmigrationProfile(
    String userId,
    ImmigrationProfile profile,
  ) async {
    await local.write(userId, profile);
    return profile;
  }

  @override
  ImmigrationProfileValidationResult validate(ImmigrationProfile profile) {
    return ImmigrationProfileValidator.validate(profile);
  }

  @override
  PathwayAssessmentResult assessPathway({
    required ImmigrationProfile profile,
    required String programId,
    required List<PathwayEligibilityRule> rules,
    DateTime? now,
  }) {
    return assessment.assess(
      profile: profile,
      programId: programId,
      rules: rules,
      now: now,
    );
  }

  @override
  Future<void> clearLocalDraft(String userId) => local.clear(userId);
}
