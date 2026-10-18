import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/knowledge/domain/research_publication_pipeline.dart';

void main() {
  late ResearchPublicationPipeline pipeline;

  setUp(() {
    pipeline = ResearchPublicationPipeline();
  });

  ResearchFindingRecord finding({
    String id = 'finding-1',
    String summary = 'Unreviewed excerpt',
  }) {
    return ResearchFindingRecord(
      id: id,
      jobId: 'job-1',
      summary: summary,
      sourceTitle: 'IRCC study permit',
      languageCode: 'en',
    );
  }

  group('finding → review candidate', () {
    test('service creates draft in review status', () {
      final result = pipeline.createReviewCandidateFromFinding(
        finding: finding(),
        actor: PipelineActorRole.service,
      );
      expect(result.isOk, isTrue);
      expect(result.value!.status, ResearchDraftStatus.review);
      expect(result.value!.findingId, 'finding-1');
      expect(result.value!.title, contains('IRCC'));
      expect(pipeline.feed, isEmpty);
    });

    test('non-service actors cannot create candidates', () {
      for (final role in [
        PipelineActorRole.user,
        PipelineActorRole.admin,
        PipelineActorRole.superAdmin,
      ]) {
        final result = pipeline.createReviewCandidateFromFinding(
          finding: finding(),
          actor: role,
        );
        expect(result.error, 'forbidden');
      }
      expect(pipeline.drafts, isEmpty);
    });

    test('duplicate finding is idempotent', () {
      final first = pipeline.createReviewCandidateFromFinding(
        finding: finding(),
        actor: PipelineActorRole.service,
      );
      final second = pipeline.createReviewCandidateFromFinding(
        finding: finding(),
        actor: PipelineActorRole.service,
      );
      expect(second.value!.id, first.value!.id);
      expect(pipeline.drafts.length, 1);
    });

    test('research path never creates feed items', () {
      pipeline.createReviewCandidateFromFinding(
        finding: finding(),
        actor: PipelineActorRole.service,
      );
      expect(pipeline.researchPathCreatesFeedItems(), isFalse);
      expect(pipeline.publishedFeedVisibleToPublic(), isEmpty);
    });
  });

  group('editorial status', () {
    test('admin can approve review draft', () {
      final created = pipeline.createReviewCandidateFromFinding(
        finding: finding(),
        actor: PipelineActorRole.service,
      );
      final approved = pipeline.setDraftStatus(
        draftId: created.value!.id,
        status: ResearchDraftStatus.approved,
        actor: PipelineActorRole.admin,
      );
      expect(approved.isOk, isTrue);
      expect(approved.value!.status, ResearchDraftStatus.approved);
    });

    test('user cannot change draft status', () {
      final created = pipeline.createReviewCandidateFromFinding(
        finding: finding(),
        actor: PipelineActorRole.service,
      );
      final result = pipeline.setDraftStatus(
        draftId: created.value!.id,
        status: ResearchDraftStatus.approved,
        actor: PipelineActorRole.user,
      );
      expect(result.error, 'forbidden');
    });

    test('cannot set published via status RPC', () {
      final created = pipeline.createReviewCandidateFromFinding(
        finding: finding(),
        actor: PipelineActorRole.service,
      );
      final result = pipeline.setDraftStatus(
        draftId: created.value!.id,
        status: ResearchDraftStatus.published,
        actor: PipelineActorRole.admin,
      );
      expect(result.error, 'invalid status');
    });
  });

  group('human-only publish', () {
    test('unapproved draft cannot be published', () {
      final created = pipeline.createReviewCandidateFromFinding(
        finding: finding(),
        actor: PipelineActorRole.service,
      );
      final result = pipeline.publishDraft(
        draftId: created.value!.id,
        actor: PipelineActorRole.admin,
      );
      expect(
        result.error,
        'draft requires explicit approval before publication',
      );
      expect(pipeline.feed, isEmpty);
    });

    test('rejected draft cannot be published', () {
      final created = pipeline.createReviewCandidateFromFinding(
        finding: finding(),
        actor: PipelineActorRole.service,
      );
      pipeline.setDraftStatus(
        draftId: created.value!.id,
        status: ResearchDraftStatus.rejected,
        actor: PipelineActorRole.admin,
      );
      final result = pipeline.publishDraft(
        draftId: created.value!.id,
        actor: PipelineActorRole.admin,
      );
      expect(
        result.error,
        'draft requires explicit approval before publication',
      );
    });

    test('user cannot publish approved draft', () {
      final created = pipeline.createReviewCandidateFromFinding(
        finding: finding(),
        actor: PipelineActorRole.service,
      );
      pipeline.setDraftStatus(
        draftId: created.value!.id,
        status: ResearchDraftStatus.approved,
        actor: PipelineActorRole.admin,
      );
      final result = pipeline.publishDraft(
        draftId: created.value!.id,
        actor: PipelineActorRole.user,
      );
      expect(result.error, 'forbidden');
      expect(pipeline.feed, isEmpty);
    });

    test('admin publishes approved draft → feed visible', () {
      final created = pipeline.createReviewCandidateFromFinding(
        finding: finding(),
        actor: PipelineActorRole.service,
      );
      pipeline.setDraftStatus(
        draftId: created.value!.id,
        status: ResearchDraftStatus.approved,
        actor: PipelineActorRole.admin,
      );
      final published = pipeline.publishDraft(
        draftId: created.value!.id,
        actor: PipelineActorRole.admin,
      );
      expect(published.isOk, isTrue);
      expect(published.value!.status, 'published');
      expect(
        pipeline.drafts[created.value!.id]!.status,
        ResearchDraftStatus.published,
      );
      expect(pipeline.publishedFeedVisibleToPublic().length, 1);
    });

    test('publish is idempotent', () {
      final created = pipeline.createReviewCandidateFromFinding(
        finding: finding(),
        actor: PipelineActorRole.service,
      );
      pipeline.setDraftStatus(
        draftId: created.value!.id,
        status: ResearchDraftStatus.approved,
        actor: PipelineActorRole.admin,
      );
      final first = pipeline.publishDraft(
        draftId: created.value!.id,
        actor: PipelineActorRole.admin,
      );
      final second = pipeline.publishDraft(
        draftId: created.value!.id,
        actor: PipelineActorRole.admin,
      );
      expect(second.value!.id, first.value!.id);
      expect(pipeline.feed.length, 1);
    });
  });

  group('isolation', () {
    test('cross-finding drafts stay separate', () {
      pipeline.createReviewCandidateFromFinding(
        finding: finding(id: 'f-a', summary: 'A'),
        actor: PipelineActorRole.service,
      );
      pipeline.createReviewCandidateFromFinding(
        finding: finding(id: 'f-b', summary: 'B'),
        actor: PipelineActorRole.service,
      );
      expect(pipeline.drafts.length, 2);
    });
  });
}
