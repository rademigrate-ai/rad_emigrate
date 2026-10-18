/// Research → review draft → editorial approval → Feed publication.
///
/// Pure domain rules mirroring Stage 1/2 + Stage 5 SQL contracts:
/// - Research/AI may only produce review candidates (content drafts in
///   status `review`).
/// - Editorial approval is explicit and human-only.
/// - Feed publication requires status `approved` and admin/super_admin.
/// - Never auto-publish. Never invent immigration content here.
library;

enum ResearchDraftStatus { draft, review, approved, rejected, published }

enum PipelineActorRole { service, user, admin, superAdmin }

class ResearchFindingRecord {
  const ResearchFindingRecord({
    required this.id,
    required this.jobId,
    required this.summary,
    this.sourceTitle,
    this.languageCode = 'en',
  });

  final String id;
  final String jobId;
  final String summary;
  final String? sourceTitle;
  final String languageCode;
}

class ContentDraftRecord {
  const ContentDraftRecord({
    required this.id,
    required this.findingId,
    required this.jobId,
    required this.title,
    required this.body,
    required this.status,
    required this.languageCode,
    this.feedItemId,
  });

  final String id;
  final String findingId;
  final String jobId;
  final String title;
  final String body;
  final ResearchDraftStatus status;
  final String languageCode;
  final String? feedItemId;

  ContentDraftRecord copyWith({
    ResearchDraftStatus? status,
    String? title,
    String? body,
    String? feedItemId,
  }) {
    return ContentDraftRecord(
      id: id,
      findingId: findingId,
      jobId: jobId,
      title: title ?? this.title,
      body: body ?? this.body,
      status: status ?? this.status,
      languageCode: languageCode,
      feedItemId: feedItemId ?? this.feedItemId,
    );
  }
}

class FeedItemRecord {
  const FeedItemRecord({
    required this.id,
    required this.draftId,
    required this.slug,
    required this.status,
  });

  final String id;
  final String draftId;
  final String slug;
  final String status;
}

class PipelineResult<T> {
  const PipelineResult._({this.value, this.error});

  factory PipelineResult.ok(T value) => PipelineResult._(value: value);
  factory PipelineResult.fail(String error) => PipelineResult._(error: error);

  final T? value;
  final String? error;

  bool get isOk => error == null;
}

/// In-memory, deterministic stand-in for the SQL pipeline used in unit tests.
/// Does not talk to Supabase. Production path remains SECURITY DEFINER RPCs.
class ResearchPublicationPipeline {
  ResearchPublicationPipeline({
    Map<String, ContentDraftRecord>? drafts,
    Map<String, FeedItemRecord>? feed,
  }) : _drafts = drafts ?? <String, ContentDraftRecord>{},
       _feed = feed ?? <String, FeedItemRecord>{};

  final Map<String, ContentDraftRecord> _drafts;
  final Map<String, FeedItemRecord> _feed;
  int _seq = 0;

  Map<String, ContentDraftRecord> get drafts => Map.unmodifiable(_drafts);
  Map<String, FeedItemRecord> get feed => Map.unmodifiable(_feed);

  /// Finding insert → review candidate. Idempotent per finding id.
  /// Service role only (mirrors grant to service_role).
  PipelineResult<ContentDraftRecord> createReviewCandidateFromFinding({
    required ResearchFindingRecord finding,
    required PipelineActorRole actor,
  }) {
    if (actor != PipelineActorRole.service) {
      return PipelineResult.fail('forbidden');
    }
    final existing = _drafts.values
        .where((d) => d.findingId == finding.id)
        .toList();
    if (existing.isNotEmpty) {
      return PipelineResult.ok(existing.first);
    }

    final title = _composeTitle(finding);
    final id = 'draft-${++_seq}';
    final draft = ContentDraftRecord(
      id: id,
      findingId: finding.id,
      jobId: finding.jobId,
      title: title,
      body: finding.summary,
      status: ResearchDraftStatus.review,
      languageCode: finding.languageCode == 'fa' ? 'fa' : 'en',
    );
    _drafts[id] = draft;
    return PipelineResult.ok(draft);
  }

  PipelineResult<ContentDraftRecord> setDraftStatus({
    required String draftId,
    required ResearchDraftStatus status,
    required PipelineActorRole actor,
  }) {
    if (!_isAdmin(actor)) return PipelineResult.fail('forbidden');
    final draft = _drafts[draftId];
    if (draft == null) return PipelineResult.fail('draft not found');
    if (draft.status == ResearchDraftStatus.published) {
      return PipelineResult.fail('draft not found or already published');
    }
    if (status == ResearchDraftStatus.published) {
      return PipelineResult.fail('invalid status');
    }
    final allowed = {
      ResearchDraftStatus.draft,
      ResearchDraftStatus.review,
      ResearchDraftStatus.approved,
      ResearchDraftStatus.rejected,
    };
    if (!allowed.contains(status)) {
      return PipelineResult.fail('invalid status');
    }
    final updated = draft.copyWith(status: status);
    _drafts[draftId] = updated;
    return PipelineResult.ok(updated);
  }

  /// Explicit human publish. Requires approved + admin. Idempotent.
  PipelineResult<FeedItemRecord> publishDraft({
    required String draftId,
    required PipelineActorRole actor,
    String? slug,
  }) {
    if (!_isAdmin(actor)) return PipelineResult.fail('forbidden');
    final draft = _drafts[draftId];
    if (draft == null) return PipelineResult.fail('draft not found');

    if (draft.status == ResearchDraftStatus.published &&
        draft.feedItemId != null) {
      final existing = _feed[draft.feedItemId!];
      if (existing != null) return PipelineResult.ok(existing);
    }

    if (draft.status != ResearchDraftStatus.approved) {
      return PipelineResult.fail(
        'draft requires explicit approval before publication',
      );
    }

    final feedId = draft.feedItemId ?? 'feed-${++_seq}';
    final resolvedSlug = (slug == null || slug.trim().isEmpty)
        ? 'rad-update-${draft.id}'
        : slug.trim().toLowerCase();
    final item = FeedItemRecord(
      id: feedId,
      draftId: draftId,
      slug: resolvedSlug,
      status: 'published',
    );
    _feed[feedId] = item;
    _drafts[draftId] = draft.copyWith(
      status: ResearchDraftStatus.published,
      feedItemId: feedId,
    );
    return PipelineResult.ok(item);
  }

  /// Research/AI path must never produce published feed items.
  bool researchPathCreatesFeedItems() => false;

  List<FeedItemRecord> publishedFeedVisibleToPublic() {
    return _feed.values.where((f) => f.status == 'published').toList();
  }

  static bool _isAdmin(PipelineActorRole actor) =>
      actor == PipelineActorRole.admin || actor == PipelineActorRole.superAdmin;

  static String _composeTitle(ResearchFindingRecord finding) {
    final source = finding.sourceTitle?.trim();
    if (source != null && source.isNotEmpty) {
      return source.length > 300 ? source.substring(0, 300) : source;
    }
    return 'Research finding';
  }
}
