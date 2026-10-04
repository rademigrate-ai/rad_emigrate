enum AssistantScope { user, admin, both }

enum SourceTrustClass {
  radOfficial,
  adminDefined,
  authoritativeExternal,
  generalWeb,
}

enum ProviderKind { openAiCompatible, anthropic, gemini }

enum FailureKind {
  authentication,
  rateLimit,
  timeout,
  server,
  malformed,
  network,
  unsupported,
}

class Evidence {
  const Evidence({
    required this.id,
    required this.url,
    required this.title,
    required this.trust,
    required this.retrievedAt,
    this.publishedAt,
    this.updatedAt,
    this.excerpt,
  });

  final String id;
  final String url;
  final String title;
  final SourceTrustClass trust;
  final DateTime retrievedAt;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final String? excerpt;
}

class EvidenceConflict {
  const EvidenceConflict(this.evidenceIds, this.summary);

  final List<String> evidenceIds;
  final String summary;
}

class UserAiRequest {
  const UserAiRequest(this.question, {this.forceResearch = false});

  final String question;
  final bool forceResearch;
}

class UserAiAnswer {
  const UserAiAnswer({
    required this.text,
    this.evidence = const [],
    this.conflicts = const [],
    this.uncertain = false,
  });

  final String text;
  final List<Evidence> evidence;
  final List<EvidenceConflict> conflicts;
  final bool uncertain;
}

class ModelCandidate {
  const ModelCandidate({
    required this.provider,
    required this.model,
    required this.priority,
    required this.scope,
    this.enabled = true,
    this.providerEnabled = true,
    this.healthy = true,
    this.cooldownUntil,
  });

  final String provider;
  final String model;
  final int priority;
  final AssistantScope scope;
  final bool enabled;
  final bool providerEnabled;
  final bool healthy;
  final DateTime? cooldownUntil;

  bool eligible(AssistantScope requested, DateTime now) =>
      enabled &&
      providerEnabled &&
      healthy &&
      (cooldownUntil == null || !cooldownUntil!.isAfter(now)) &&
      (scope == AssistantScope.both || scope == requested);
}

class AttemptResult {
  const AttemptResult(this.candidate, this.success, {this.failure});

  final ModelCandidate candidate;
  final bool success;
  final FailureKind? failure;
}

class FallbackResult {
  const FallbackResult({required this.attempts, required this.succeeded});

  final List<AttemptResult> attempts;
  final bool succeeded;

  bool get failed => !succeeded;
}

class FallbackEngine {
  const FallbackEngine({this.maxAttempts = 3}) : assert(maxAttempts >= 0);

  final int maxAttempts;

  Future<FallbackResult> run({
    required AssistantScope scope,
    required List<ModelCandidate> candidates,
    required DateTime now,
    required Future<FailureKind?> Function(ModelCandidate) attempt,
  }) async {
    final eligible = candidates.where((c) => c.eligible(scope, now)).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    final attempts = <AttemptResult>[];
    for (final candidate in eligible.take(maxAttempts)) {
      final failure = await attempt(candidate);
      attempts.add(
        AttemptResult(candidate, failure == null, failure: failure),
      );
      if (failure == null) {
        return FallbackResult(attempts: attempts, succeeded: true);
      }
    }
    return FallbackResult(attempts: attempts, succeeded: false);
  }
}

class FailurePolicy {
  const FailurePolicy({
    required this.retryable,
    required this.fallback,
    required this.cooldown,
    required this.configurationError,
  });

  final bool retryable;
  final bool fallback;
  final bool cooldown;
  final bool configurationError;
}

FailurePolicy classifyFailure(FailureKind kind) => switch (kind) {
  FailureKind.authentication => const FailurePolicy(
    retryable: false,
    fallback: true,
    cooldown: false,
    configurationError: true,
  ),
  FailureKind.rateLimit => const FailurePolicy(
    retryable: true,
    fallback: true,
    cooldown: true,
    configurationError: false,
  ),
  FailureKind.timeout || FailureKind.server || FailureKind.network =>
    const FailurePolicy(
      retryable: true,
      fallback: true,
      cooldown: false,
      configurationError: false,
    ),
  FailureKind.malformed || FailureKind.unsupported => const FailurePolicy(
    retryable: false,
    fallback: true,
    cooldown: false,
    configurationError: false,
  ),
};

String sanitizedFailureMessage(FailureKind kind) => switch (kind) {
  FailureKind.authentication => 'AI provider configuration is unavailable.',
  FailureKind.rateLimit => 'AI provider is temporarily rate limited.',
  FailureKind.timeout => 'AI provider timed out.',
  FailureKind.server => 'AI provider is temporarily unavailable.',
  FailureKind.malformed => 'AI provider returned an invalid response.',
  FailureKind.network => 'AI provider could not be reached.',
  FailureKind.unsupported => 'AI provider operation is unsupported.',
};

abstract interface class AiProviderAdapter {
  ProviderKind get kind;
  Future<bool> testConnection();
  Future<List<String>> discoverModels();
  Future<String> generate(String prompt);
}

class ModelSyncResult {
  const ModelSyncResult({
    required this.added,
    required this.retained,
    required this.removed,
  });

  final Set<String> added;
  final Set<String> retained;
  final Set<String> removed;
}

ModelSyncResult synchronizeModels(
  Set<String> existing,
  Iterable<String> discovered,
) {
  final clean = discovered
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();
  return ModelSyncResult(
    added: clean.difference(existing),
    retained: clean.intersection(existing),
    removed: existing.difference(clean),
  );
}

class DiscoveredModel {
  const DiscoveredModel({required this.id, this.enabled = false});

  final String id;
  final bool enabled;
}

List<DiscoveredModel> newlyDiscoveredModels(ModelSyncResult sync) =>
    sync.added.map((id) => DiscoveredModel(id: id)).toList(growable: false);

class WebSearchResult {
  const WebSearchResult({
    required this.url,
    required this.title,
    required this.snippet,
    required this.trust,
    required this.retrievedAt,
    this.publishedAt,
    this.updatedAt,
  });

  final String url;
  final String title;
  final String snippet;
  final SourceTrustClass trust;
  final DateTime retrievedAt;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
}

abstract interface class WebResearch {
  Future<List<WebSearchResult>> search(String query);
}

abstract interface class KnowledgeRetriever {
  Future<List<Evidence>> retrieve(String query, AssistantScope scope);
}

List<Evidence> normalizeEvidence(Iterable<Evidence> items) {
  final byKey = <String, Evidence>{};
  for (final evidence in items) {
    final key = evidence.url.trim().toLowerCase();
    final old = byKey[key];
    if (old == null ||
        (evidence.updatedAt ?? evidence.retrievedAt).isAfter(
          old.updatedAt ?? old.retrievedAt,
        )) {
      byKey[key] = evidence;
    }
  }
  final out = byKey.values.toList()
    ..sort(
      (a, b) => (b.updatedAt ?? b.retrievedAt).compareTo(
        a.updatedAt ?? a.retrievedAt,
      ),
    );
  return out;
}

class PromptEnvelope {
  const PromptEnvelope({
    required this.system,
    required this.trustedContext,
    required this.untrustedRetrievedContent,
    required this.userQuestion,
  });

  final String system;
  final String trustedContext;
  final String untrustedRetrievedContent;
  final String userQuestion;

  String render() =>
      '<SYSTEM>\n$system\n</SYSTEM>\n'
      '<TRUSTED_APPLICATION_CONTEXT>\n$trustedContext\n'
      '</TRUSTED_APPLICATION_CONTEXT>\n'
      '<UNTRUSTED_RETRIEVED_CONTENT>\n$untrustedRetrievedContent\n'
      '</UNTRUSTED_RETRIEVED_CONTENT>\n'
      '<USER_QUESTION>\n$userQuestion\n</USER_QUESTION>';
}

enum AiCapability {
  ask,
  research,
  manageProviders,
  manageSources,
  review,
  approve,
  publish,
  manageRoles,
  retrieveSecrets,
}

Set<AiCapability> capabilitiesFor(AssistantScope scope) => switch (scope) {
  AssistantScope.user => {AiCapability.ask, AiCapability.research},
  AssistantScope.admin => {
    AiCapability.ask,
    AiCapability.research,
    AiCapability.manageProviders,
    AiCapability.manageSources,
    AiCapability.review,
    AiCapability.approve,
  },
  AssistantScope.both => {AiCapability.ask, AiCapability.research},
};

enum ChangeKind { unchanged, contentChanged, unavailable, error }

String normalizeSourceText(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();

ChangeKind detectChange(
  String? previous,
  String? current, {
  bool error = false,
}) {
  if (error) return ChangeKind.error;
  if (current == null) return ChangeKind.unavailable;
  if (previous == null ||
      normalizeSourceText(previous) != normalizeSourceText(current)) {
    return ChangeKind.contentChanged;
  }
  return ChangeKind.unchanged;
}

class ResearchEvidence {
  const ResearchEvidence(this.items);

  final List<Evidence> items;
}

class ResearchSynthesis {
  const ResearchSynthesis(this.summary);

  final String summary;
}

class DraftFinding {
  const DraftFinding({required this.title, required this.summary});

  final String title;
  final String summary;
}

class ReviewCandidate {
  const ReviewCandidate({
    required this.title,
    required this.summary,
    required this.evidence,
    required this.conflicts,
  });

  final String title;
  final String summary;
  final List<Evidence> evidence;
  final List<EvidenceConflict> conflicts;
}

class AdminResearchResult {
  const AdminResearchResult({
    required this.evidence,
    required this.conflicts,
    required this.synthesis,
    required this.draftFinding,
    required this.reviewCandidate,
  });

  final ResearchEvidence evidence;
  final List<EvidenceConflict> conflicts;
  final ResearchSynthesis synthesis;
  final DraftFinding draftFinding;
  final ReviewCandidate reviewCandidate;
}

abstract interface class AdminResearchPipeline {
  Future<AdminResearchResult> research(String sourceId);
}

// Deliberately no publish, role-management, or secret-retrieval operation:
// those remain separate human-authorized/service-only boundaries.
