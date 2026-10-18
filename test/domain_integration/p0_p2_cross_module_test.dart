import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/ai_assistant/domain/ai_authorization.dart';
import 'package:rad_emigrate/features/ai_assistant/domain/voice_ai_contract.dart';
import 'package:rad_emigrate/features/documents/domain/ocr_result_interpreter.dart';
import 'package:rad_emigrate/features/knowledge/domain/research_publication_pipeline.dart';

/// Cross-module domain contracts for P0–P2.
void main() {
  test('AI auth gate blocks cross-account before voice session use', () {
    const auth = AiAuthorization();
    final deny = auth.authorizeOwnedResource(
      session: const AiSessionContext(
        callerRole: AiCallerRole.user,
        callerUserId: 'user-a',
      ),
      resourceOwnerId: 'user-b',
    );
    expect(deny.allowed, isFalse);

    // Voice may only proceed when ownership is allowed.
    final allow = auth.authorizeOwnedResource(
      session: const AiSessionContext(
        callerRole: AiCallerRole.user,
        callerUserId: 'user-a',
      ),
      resourceOwnerId: 'user-a',
    );
    expect(allow.allowed, isTrue);
    final voice = VoiceAiContract().startListening(locale: 'fa');
    expect(voice.state, VoiceSessionState.listening);
  });

  test('research never publishes; OCR owner mismatch hides fields', () {
    final pipeline = ResearchPublicationPipeline();
    final draft = pipeline.createReviewCandidateFromFinding(
      finding: const ResearchFindingRecord(
        id: 'f1',
        jobId: 'j1',
        summary: 'Excerpt',
      ),
      actor: PipelineActorRole.service,
    );
    expect(draft.isOk, isTrue);
    expect(pipeline.feed, isEmpty);

    final byUser = pipeline.publishDraft(
      draftId: draft.value!.id,
      actor: PipelineActorRole.user,
    );
    expect(byUser.error, 'forbidden');

    const ocr = OcrResultInterpreter();
    final interp = ocr.interpret(
      job: const OcrJobSnapshot(
        jobId: 'j',
        documentId: 'd',
        ownerUserId: 'owner',
        status: OcrJobStatus.reviewRequired,
        fields: [OcrFieldExtraction(key: 'name', value: 'X', confidence: 0.9)],
      ),
      callerUserId: 'other',
    );
    expect(interp.displayableFields, isEmpty);
    expect(interp.failure, OcrFailureCode.ownerMismatch);
  });

  test('approved human publish is the only feed path', () {
    final pipeline = ResearchPublicationPipeline();
    final created = pipeline.createReviewCandidateFromFinding(
      finding: const ResearchFindingRecord(
        id: 'f2',
        jobId: 'j2',
        summary: 'Excerpt',
        sourceTitle: 'RAD source',
      ),
      actor: PipelineActorRole.service,
    );
    pipeline.setDraftStatus(
      draftId: created.value!.id,
      status: ResearchDraftStatus.approved,
      actor: PipelineActorRole.admin,
    );
    final pub = pipeline.publishDraft(
      draftId: created.value!.id,
      actor: PipelineActorRole.admin,
    );
    expect(pub.isOk, isTrue);
    expect(pipeline.publishedFeedVisibleToPublic(), hasLength(1));
  });
}
