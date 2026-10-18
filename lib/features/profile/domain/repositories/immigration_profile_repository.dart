import '../entities/profile_entity.dart';
import '../immigration_profile_validator.dart';
import '../pathway_assessment.dart';

/// Contract for immigration (structured) profile persistence and assessment.
/// Implementations must enforce per-user ownership at the data boundary.
abstract class ImmigrationProfileRepository {
  /// Load structured immigration profile for [userId], or null if none.
  Future<ImmigrationProfile?> getImmigrationProfile(String userId);

  /// Persist a draft or complete profile for [userId].
  /// Caller is responsible for ensuring [userId] matches the authenticated user.
  Future<ImmigrationProfile> saveImmigrationProfile(
    String userId,
    ImmigrationProfile profile,
  );

  /// Structural validation only (no eligibility rules).
  ImmigrationProfileValidationResult validate(ImmigrationProfile profile);

  /// Pathway assessment against curated rules only.
  PathwayAssessmentResult assessPathway({
    required ImmigrationProfile profile,
    required String programId,
    required List<PathwayEligibilityRule> rules,
    DateTime? now,
  });
}
