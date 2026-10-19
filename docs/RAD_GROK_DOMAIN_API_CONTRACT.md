# Grok Domain API Contract for Antigravity

**Branch:** `feat/grok-independent-feature-completion`  
**Primary hardening SHA:** (see progress doc after commit)  
**Scope:** Pure Dart domain + local adapters. No Flutter UI ownership.

---

## 1. Immigration profile

```dart
import 'package:rad_emigrate/features/profile/domain/entities/profile_entity.dart';
import 'package:rad_emigrate/features/profile/domain/immigration_profile_validator.dart';
import 'package:rad_emigrate/features/profile/domain/repositories/immigration_profile_repository.dart';

// Validate (structural only)
final result = ImmigrationProfileValidator.validate(profile);
// result.completenessPercent, result.missingFields, result.invalidFields

// Draft R/W — always pass authenticated userId
await repo.saveImmigrationProfile(userId, profile);
final draft = await repo.getImmigrationProfile(userId);

// Logout / account switch
await repo.clearLocalDraft(userId);
```

**Uncertainty:** unknown fields via `profile.markUnknown(field)`.

---

## 2. Pathway assessment

```dart
import 'package:rad_emigrate/features/profile/domain/pathway_assessment.dart';

final outcome = const PathwayAssessmentService().assess(
  profile: profile,
  programId: 'ca-express',
  rules: curatedRules, // empty → insufficientVerifiedEvidence
  now: DateTime.now().toUtc(),
);
// outcome.outcome: potentiallyEligible | insufficientInformation |
//   potentiallyIneligible | requiresProfessionalReview | insufficientVerifiedEvidence
```

Never invent rules. Empty `rules` is fail-closed.

---

## 3. Knowledge integrity

```dart
import 'package:rad_emigrate/features/knowledge/domain/knowledge_integrity.dart';

final report = const KnowledgeIntegrityService().evaluate(
  sources: sources,
  claims: claims,
  now: DateTime.now().toUtc(),
);
// report.conflicts, report.aiOnlyTopics, report.hasInsufficientEvidence,
// report.requiresHumanReview, report.hasExpiredAuthoritativeEvidence
```

AI-generated sources never sole basis for eligibility.

---

## 4. Recommendations

```dart
import 'package:rad_emigrate/features/profile/domain/recommendation_engine.dart';

final report = const RecommendationEngine().recommend(
  profile: profile,
  candidateProgramIds: programIds,
  rules: curatedRules,
  now: DateTime.now().toUtc(),
);
// report.included — only potentiallyEligible
// each ProgramRecommendation.decision + .explanation + .rankScore (preference only)
```

---

## 5. Case lifecycle & checklist

```dart
import 'package:rad_emigrate/features/applications/domain/case_lifecycle.dart';

const svc = CaseLifecycleService();
svc.assertOwnership(immigrationCase, actorUserId);

final next = svc.transitionApplicationStatus(
  case_: immigrationCase,
  actorUserId: actorUserId,
  next: ApplicationStatus.submitted,
);

final done = svc.completeChecklistItemOnce(
  case_: next,
  actorUserId: actorUserId,
  itemId: 'doc-1',
);

// Reminder metadata ≠ delivered notification
final reminders = svc.pendingReminders(done);
```

---

## 6. University / scholarship search

```dart
import 'package:rad_emigrate/features/visa/domain/entities/university_scholarship.dart';

final result = catalog.searchPrograms(
  UniversitySearchFilter(countryCode: 'CA', requireFreshSource: true),
);
// result.state: empty | unknownSource | expiredSource | conflict | data
```

Empty catalog → `CatalogResultState.empty` (fail-closed).

---

## 7. Local storage isolation (security)

| Store | Key pattern | Clear on logout |
|-------|-------------|-----------------|
| Immigration profile draft | `rad_immigration_profile_{userId}` | `clearLocalDraft` / `clearAllImmigrationDrafts` |
| Applications cache | `rad_applications_{userId}` | `clearForUser` |

**Not encrypted at rest.** SharedPreferences is device-local plaintext. Do not claim encryption. Production isolation = Supabase RLS.

**API change (compatible):** `ApplicationLocalDataSource.writeForUser` / `readForUser` preferred over legacy unscoped `writeAll`/`readAll`.

---

## 8. Error codes (domain)

`CaseLifecycleException.code`:
- `ownership_denied`
- `missing_owner`
- `invalid_status_transition`
- `invalid_checklist_transition`
- `duplicate_action`
- `item_not_found`

Messages must not embed full profile PII (use ids only).
