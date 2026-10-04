enum AssistantScope { user, admin, both }
enum SourceTrustClass { radOfficial, adminDefined, authoritativeExternal, generalWeb }
enum ProviderKind { openAiCompatible, anthropic, gemini }
enum FailureKind { authentication, rateLimit, timeout, server, malformed, network, unsupported }

class Evidence {
  const Evidence({required this.id, required this.url, required this.title, required this.trust, required this.retrievedAt, this.updatedAt, this.excerpt});
  final String id, url, title;
  final SourceTrustClass trust;
  final DateTime retrievedAt;
  final DateTime? updatedAt;
  final String? excerpt;
}
class EvidenceConflict { const EvidenceConflict(this.evidenceIds, this.summary); final List<String> evidenceIds; final String summary; }
class UserAiRequest { const UserAiRequest(this.question, {this.forceResearch=false}); final String question; final bool forceResearch; }
class UserAiAnswer { const UserAiAnswer({required this.text, this.evidence=const [], this.conflicts=const [], this.uncertain=false}); final String text; final List<Evidence> evidence; final List<EvidenceConflict> conflicts; final bool uncertain; }

class ModelCandidate {
 const ModelCandidate({required this.provider, required this.model, required this.priority, required this.scope, this.enabled=true, this.healthy=true, this.cooldownUntil});
 final String provider, model; final int priority; final AssistantScope scope; final bool enabled, healthy; final DateTime? cooldownUntil;
 bool eligible(AssistantScope requested, DateTime now) => enabled && healthy && (cooldownUntil == null || !cooldownUntil!.isAfter(now)) && (scope == AssistantScope.both || scope == requested);
}
class AttemptResult { const AttemptResult(this.candidate, this.success, {this.failure}); final ModelCandidate candidate; final bool success; final FailureKind? failure; }
class FallbackEngine {
 const FallbackEngine({this.maxAttempts=3}); final int maxAttempts;
 Future<List<AttemptResult>> run({required AssistantScope scope, required List<ModelCandidate> candidates, required DateTime now, required Future<FailureKind?> Function(ModelCandidate) attempt}) async {
  final eligible = candidates.where((c)=>c.eligible(scope, now)).toList()..sort((a,b)=>a.priority.compareTo(b.priority));
  final out=<AttemptResult>[];
  for (final c in eligible.take(maxAttempts)) { final failure=await attempt(c); out.add(AttemptResult(c, failure==null, failure: failure)); if(failure==null) break; }
  return out;
 }
}
class FailurePolicy { const FailurePolicy({required this.retryable, required this.fallback, required this.cooldown, required this.configurationError}); final bool retryable,fallback,cooldown,configurationError; }
FailurePolicy classifyFailure(FailureKind kind) => switch(kind) {
 FailureKind.authentication => const FailurePolicy(retryable:false,fallback:true,cooldown:false,configurationError:true),
 FailureKind.rateLimit => const FailurePolicy(retryable:true,fallback:true,cooldown:true,configurationError:false),
 FailureKind.timeout || FailureKind.server || FailureKind.network => const FailurePolicy(retryable:true,fallback:true,cooldown:false,configurationError:false),
 FailureKind.malformed || FailureKind.unsupported => const FailurePolicy(retryable:false,fallback:true,cooldown:false,configurationError:false),
};

abstract interface class AiProviderAdapter {
 ProviderKind get kind;
 Future<bool> testConnection();
 Future<List<String>> discoverModels();
 Future<String> generate(String prompt);
}
class ModelSyncResult { const ModelSyncResult({required this.added,required this.retained,required this.removed}); final Set<String> added,retained,removed; }
ModelSyncResult synchronizeModels(Set<String> existing, Iterable<String> discovered) { final clean=discovered.map((e)=>e.trim()).where((e)=>e.isNotEmpty).toSet(); return ModelSyncResult(added:clean.difference(existing), retained:clean.intersection(existing), removed:existing.difference(clean)); }

class WebSearchResult { const WebSearchResult({required this.url,required this.title,required this.snippet,required this.trust,required this.retrievedAt,this.updatedAt}); final String url,title,snippet; final SourceTrustClass trust; final DateTime retrievedAt; final DateTime? updatedAt; }
abstract interface class WebResearch { Future<List<WebSearchResult>> search(String query); }
abstract interface class KnowledgeRetriever { Future<List<Evidence>> retrieve(String query, AssistantScope scope); }

List<Evidence> normalizeEvidence(Iterable<Evidence> items) { final byKey=<String,Evidence>{}; for(final e in items){final key=e.url.trim().toLowerCase(); final old=byKey[key]; if(old==null || (e.updatedAt??e.retrievedAt).isAfter(old.updatedAt??old.retrievedAt)) byKey[key]=e;} final out=byKey.values.toList()..sort((a,b)=>(b.updatedAt??b.retrievedAt).compareTo(a.updatedAt??a.retrievedAt)); return out; }

class PromptEnvelope {
 const PromptEnvelope({required this.system,required this.trustedContext,required this.untrustedRetrievedContent,required this.userQuestion});
 final String system,trustedContext,untrustedRetrievedContent,userQuestion;
 String render() => '<SYSTEM>\n$system\n</SYSTEM>\n<TRUSTED_APPLICATION_CONTEXT>\n$trustedContext\n</TRUSTED_APPLICATION_CONTEXT>\n<UNTRUSTED_RETRIEVED_CONTENT>\n$untrustedRetrievedContent\n</UNTRUSTED_RETRIEVED_CONTENT>\n<USER_QUESTION>\n$userQuestion\n</USER_QUESTION>';
}

enum AiCapability { ask, research, manageProviders, manageSources, review, approve, publish, manageRoles, retrieveSecrets }
Set<AiCapability> capabilitiesFor(AssistantScope scope) => switch(scope) {
 AssistantScope.user => {AiCapability.ask, AiCapability.research},
 AssistantScope.admin => {AiCapability.ask,AiCapability.research,AiCapability.manageProviders,AiCapability.manageSources,AiCapability.review,AiCapability.approve},
 AssistantScope.both => {AiCapability.ask,AiCapability.research},
};

enum ChangeKind { unchanged, contentChanged, unavailable, error }
String normalizeSourceText(String value)=>value.replaceAll(RegExp(r'\s+'),' ').trim();
ChangeKind detectChange(String? previous,String? current,{bool error=false}) { if(error) return ChangeKind.error; if(current==null) return ChangeKind.unavailable; if(previous==null || normalizeSourceText(previous)!=normalizeSourceText(current)) return ChangeKind.contentChanged; return ChangeKind.unchanged; }

class ReviewCandidate { const ReviewCandidate({required this.title,required this.summary,required this.evidence,required this.conflicts}); final String title,summary; final List<Evidence> evidence; final List<EvidenceConflict> conflicts; }
abstract interface class AdminResearchPipeline { Future<ReviewCandidate> research(String sourceId); }
// Deliberately no publish operation: publication is a separate human-authorized boundary.
