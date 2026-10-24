import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/rad_contract.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../domain/entities/admin_cms_entities.dart';

class CmsException implements Exception {
  const CmsException(this.code);
  final String code;
  @override
  String toString() => switch (code) {
    'unauthorized' => 'دسترسی مدیریت لازم است. دوباره وارد شوید.',
    'conflict' =>
      'نسخه مقاله تغییر کرده است؛ قبل از تلاش مجدد نسخه جدید را بررسی کنید.',
    'unavailable' => 'سرویس مدیریت محتوا در دسترس نیست.',
    'malformed' => 'پاسخ سرویس معتبر نیست؛ عملیات تأیید نشد.',
    _ => 'ارتباط با سرویس ناموفق بود. تغییرات شما حفظ شده است.',
  };
}

/// Lossless draft input, separate from the public display projection.
class CmsArticleDraft {
  CmsArticleDraft._(this._content, this.revisionId);
  final Map<String, dynamic> _content;
  final String revisionId;
  String get id => _content['article_id'] as String;
  String get locale => _content['locale'] as String;
  int get revision => _content['expected_revision'] as int;
  String get title => _content['title'] as String;
  String get summary => _content['summary'] as String;
  List<Map<String, dynamic>> get rawSections =>
      ((_content['sections'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  List<String> get relatedArticleIds =>
      ((_content['related_article_ids'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
  String? get mergeManifestId => _content['merge_manifest_id'] as String?;

  Map<String, dynamic> request({
    required String title,
    required String summary,
    List<Map<String, dynamic>>? sections,
    required String requestKey,
  }) {
    final req =
        (jsonDecode(jsonEncode(_content)) as Map).cast<String, dynamic>()
          ..['title'] = title
          ..['summary'] = summary
          ..['request_key'] = requestKey;
    if (sections != null) {
      req['sections'] = sections;
    }
    return req;
  }
}

abstract class AdminCmsRepository {
  Future<List<AdminCmsArticleListItem>> listCmsArticles();
  Future<CmsArticleDraft> getArticleDraft(
    String articleId, {
    String locale = 'fa',
  });
  Future<List<AdminSourceChangeProposal>> listProposals();
  Future<AdminSourceChangeProposal?> getProposalDetail(String proposalId);
  Future<bool> reviewProposal({
    required String proposalId,
    required int expectedRevision,
    required SourceProposalReviewStatus decision,
    String? reviewerNotes,
  });
  Future<bool> saveCanonicalArticle(
    CmsArticleDraft article, {
    required String title,
    required String summary,
    List<Map<String, dynamic>>? sections,
    required String requestKey,
  });

  // Full CMS Revision Lifecycle
  Future<ArticleRevisionResult> submitArticleReview({
    required String articleId,
    required String revisionId,
    required int expectedRevision,
    required String contentHash,
    required String note,
    required String requestKey,
  });

  Future<ArticleRevisionResult> approveArticleRevision({
    required String articleId,
    required String revisionId,
    required int expectedRevision,
    required String contentHash,
    required String note,
    required String requestKey,
  });

  Future<ArticleRevisionResult> rejectArticleRevision({
    required String articleId,
    required String revisionId,
    required int expectedRevision,
    required String contentHash,
    required String note,
    required String requestKey,
  });

  Future<PublicationResult> publishArticleRevision({
    required String articleId,
    required String revisionId,
    required String contentHash,
    required String requestKey,
  });

  Future<ArticleRevisionResult> rollbackArticle({
    required String articleId,
    required String locale,
    required String fromRevisionId,
    required int expectedRevision,
    required String reason,
    required String requestKey,
  });

  Future<List<RevisionSummary>> listArticleRevisions({
    required String articleId,
    required String locale,
  });

  // Source & Authority Lifecycle
  Future<List<Authority>> listOfficialAuthorities({
    String? countryCode,
    String? topic,
    String? state,
  });

  Future<Map<String, dynamic>> discoverOfficialAuthorities({
    required String countryCode,
    required String topic,
    String? profession,
    required String requestKey,
  });

  Future<Map<String, dynamic>> enqueueResearchRefresh({
    required List<String> authorityIds,
    required String requestKey,
  });

  Future<Map<String, dynamic>> approveVisaSourceInventory({
    required String articleId,
    required List<String> sourceSnapshotIds,
    required int expectedInventoryRevision,
    required String requestKey,
  });
}

class SupabaseAdminCmsRepository implements AdminCmsRepository {
  SupabaseAdminCmsRepository(
    this._service, {
    this.timeout = const Duration(seconds: 15),
    this.maxPagesPerList = 200,
  }) : _owner = _service.isInitialized
           ? _service.client.auth.currentUser?.id
           : null;
  final Duration timeout;
  // Bound distinct-cursor responses as well as cycles; never return a partial
  // list as a complete administrative view when the budget is exhausted.
  final int maxPagesPerList;
  final SupabaseClientService _service;
  final String? _owner;

  void _assertSession() {
    if (!_service.isInitialized) throw const CmsException('unavailable');
    if (_owner == null || _service.client.auth.currentUser?.id != _owner) {
      throw const CmsException('unauthorized');
    }
  }

  Future<Map<String, dynamic>> _rpc(
    String name,
    Map<String, dynamic> request,
    String responseSchema,
  ) async {
    _assertSession();
    try {
      requireRadContract('${name}_request', request);
      final response = await _service.client
          .rpc(name, params: {'p_request': request})
          .timeout(timeout);
      _assertSession();
      requireRadContract(responseSchema, response);
      final result = (response as Map).cast<String, dynamic>();
      final meta = result['meta'] as Map;
      if (request.containsKey('locale') &&
          (meta['resolved_locale'] != request['locale'] ||
              meta['requested_locale'] != request['locale'])) {
        throw const FormatException('invalid_locale');
      }
      if (result['page'] is Map) {
        final page = result['page'] as Map;
        final items = (result['data'] as Map)['items'] as List;
        if (page['has_more'] == true && items.isEmpty ||
            page['has_more'] != (page['next_cursor'] != null) ||
            page['next_cursor'] != null &&
                page['next_cursor'] == request['cursor']) {
          throw const FormatException('invalid_page');
        }
      }
      return result;
    } on CmsException {
      rethrow;
    } on FormatException {
      throw const CmsException('malformed');
    } on PostgrestException catch (e) {
      throw CmsException(switch (e.code) {
        '42501' || 'PT401' || 'PT403' || '401' || '403' => 'unauthorized',
        'PT409' || '409' => 'conflict',
        'PGRST202' || '42883' => 'unavailable',
        _ => 'network',
      });
    } catch (_) {
      throw const CmsException('network');
    }
  }

  @override
  Future<List<AdminCmsArticleListItem>> listCmsArticles() async {
    final articles = <AdminCmsArticleListItem>[];
    for (final locale in ['fa', 'en']) {
      String? cursor;
      final visited = <String?>{};
      final identities = <String>{};
      do {
        if (visited.length >= maxPagesPerList || !visited.add(cursor)) {
          throw const CmsException('malformed');
        }
        final response = await _rpc('list_cms_articles', {
          'locale': locale,
          'cursor': cursor,
          'limit': 50,
        }, 'list_cms_articles_response');
        final items = (response['data'] as Map)['items'] as List;
        if (items.any(
          (item) =>
              (item as Map)['locale'] != locale ||
              !identities.add(item['id'] as String),
        )) {
          throw const CmsException('malformed');
        }
        articles.addAll(
          items.map(
            (e) => AdminCmsArticleListItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          ),
        );
        cursor = (response['page'] as Map)['next_cursor'] as String?;
      } while (cursor != null);
    }
    return articles;
  }

  @override
  Future<CmsArticleDraft> getArticleDraft(
    String articleId, {
    String locale = 'fa',
  }) async {
    final response = await _rpc('get_cms_article_draft', {
      'article_id': articleId,
      'locale': locale,
    }, 'get_cms_article_draft_response');
    final data = response['data'] as Map;
    final content = Map<String, dynamic>.from(data['content'] as Map);
    if (content['article_id'] != articleId ||
        content['locale'] != locale ||
        content['expected_revision'] != data['revision'] ||
        (response['meta'] as Map)['resolved_locale'] != locale) {
      throw const CmsException('malformed');
    }
    return CmsArticleDraft._(content, data['revision_id'] as String);
  }

  @override
  Future<List<AdminSourceChangeProposal>> listProposals() async {
    final proposals = <AdminSourceChangeProposal>[];
    String? cursor;
    final visited = <String?>{};
    final identities = <String>{};
    do {
      if (visited.length >= maxPagesPerList || !visited.add(cursor)) {
        throw const CmsException('malformed');
      }
      final response = await _rpc('list_research_proposals', {
        'editorial_state': null,
        'verification_state': null,
        'article_id': null,
        'cursor': cursor,
        'limit': 50,
      }, 'list_research_proposals_response');
      final items = (response['data'] as Map)['items'] as List;
      if (items.any((item) => !identities.add((item as Map)['id'] as String))) {
        throw const CmsException('malformed');
      }
      proposals.addAll(
        items.map(
          (e) => AdminSourceChangeProposal.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        ),
      );
      cursor = (response['page'] as Map)['next_cursor'] as String?;
    } while (cursor != null);
    return proposals;
  }

  @override
  Future<AdminSourceChangeProposal?> getProposalDetail(
    String proposalId,
  ) async {
    final response = await _rpc('get_research_proposal', {
      'proposal_id': proposalId,
    }, 'get_research_proposal_response');
    final proposal = AdminSourceChangeProposal.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
    if (proposal.id != proposalId) throw const CmsException('malformed');
    return proposal;
  }

  @override
  Future<bool> reviewProposal({
    required String proposalId,
    required int expectedRevision,
    required SourceProposalReviewStatus decision,
    String? reviewerNotes,
  }) async {
    if (decision == SourceProposalReviewStatus.pending) {
      throw const CmsException('malformed');
    }
    final response = await _rpc('review_research_proposal', {
      'proposal_id': proposalId,
      'expected_revision': expectedRevision,
      'decision': decision == SourceProposalReviewStatus.approved
          ? 'accept'
          : 'reject',
      'note': reviewerNotes ?? '',
      'request_key': newRadRequestKey(),
    }, 'review_research_proposal_response');
    final data = response['data'] as Map;
    final proposal = data['proposal'] as Map;
    final accepted = decision == SourceProposalReviewStatus.approved;
    final draft = data['draft_revision'];
    if (proposal['id'] != proposalId ||
        proposal['revision'] != expectedRevision + 1 ||
        proposal['editorial_state'] != (accepted ? 'approved' : 'rejected') ||
        (accepted
            ? draft is! Map ||
                  draft['article_id'] != proposal['target_article_id'] ||
                  draft['editorial_state'] != 'draft'
            : draft != null)) {
      throw const CmsException('malformed');
    }
    return true;
  }

  @override
  Future<bool> saveCanonicalArticle(
    CmsArticleDraft article, {
    required String title,
    required String summary,
    List<Map<String, dynamic>>? sections,
    required String requestKey,
  }) async {
    final request = article.request(
      title: title,
      summary: summary,
      sections: sections,
      requestKey: requestKey,
    );
    requireRadContract('save_visa_article_draft_request', request);
    final response = await _rpc(
      'save_visa_article_draft',
      request,
      'save_visa_article_draft_response',
    );
    final data = response['data'] as Map;
    if (data['article_id'] != article.id ||
        data['revision'] != article.revision + 1 ||
        data['editorial_state'] != 'draft' ||
        (response['meta'] as Map)['resolved_locale'] != article.locale) {
      throw const CmsException('malformed');
    }
    return true;
  }

  @override
  Future<ArticleRevisionResult> submitArticleReview({
    required String articleId,
    required String revisionId,
    required int expectedRevision,
    required String contentHash,
    required String note,
    required String requestKey,
  }) async {
    final response = await _rpc('submit_visa_article_review', {
      'article_id': articleId,
      'revision_id': revisionId,
      'expected_revision': expectedRevision,
      'content_hash': contentHash,
      'note': note,
      'request_key': requestKey,
    }, 'submit_visa_article_review_response');
    final result = ArticleRevisionResult.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
    if (result.articleId != articleId ||
        result.revisionId != revisionId ||
        result.editorialState != ArticleEditorialStatus.inReview) {
      throw const CmsException('malformed');
    }
    return result;
  }

  @override
  Future<ArticleRevisionResult> approveArticleRevision({
    required String articleId,
    required String revisionId,
    required int expectedRevision,
    required String contentHash,
    required String note,
    required String requestKey,
  }) async {
    final response = await _rpc('approve_visa_article_revision', {
      'article_id': articleId,
      'revision_id': revisionId,
      'expected_revision': expectedRevision,
      'content_hash': contentHash,
      'note': note,
      'request_key': requestKey,
    }, 'approve_visa_article_revision_response');
    final result = ArticleRevisionResult.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
    if (result.articleId != articleId ||
        result.revisionId != revisionId ||
        result.editorialState != ArticleEditorialStatus.approved) {
      throw const CmsException('malformed');
    }
    return result;
  }

  @override
  Future<ArticleRevisionResult> rejectArticleRevision({
    required String articleId,
    required String revisionId,
    required int expectedRevision,
    required String contentHash,
    required String note,
    required String requestKey,
  }) async {
    final response = await _rpc('reject_visa_article_revision', {
      'article_id': articleId,
      'revision_id': revisionId,
      'expected_revision': expectedRevision,
      'content_hash': contentHash,
      'note': note,
      'request_key': requestKey,
    }, 'reject_visa_article_revision_response');
    final result = ArticleRevisionResult.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
    if (result.articleId != articleId || result.revisionId != revisionId) {
      throw const CmsException('malformed');
    }
    return result;
  }

  @override
  Future<PublicationResult> publishArticleRevision({
    required String articleId,
    required String revisionId,
    required String contentHash,
    required String requestKey,
  }) async {
    final response = await _rpc('publish_visa_article_revision', {
      'article_id': articleId,
      'revision_id': revisionId,
      'content_hash': contentHash,
      'request_key': requestKey,
    }, 'publish_visa_article_revision_response');
    final result = PublicationResult.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
    if (result.resourceId != articleId || result.revisionId != revisionId) {
      throw const CmsException('malformed');
    }
    return result;
  }

  @override
  Future<ArticleRevisionResult> rollbackArticle({
    required String articleId,
    required String locale,
    required String fromRevisionId,
    required int expectedRevision,
    required String reason,
    required String requestKey,
  }) async {
    final response = await _rpc('rollback_visa_article', {
      'article_id': articleId,
      'locale': locale,
      'from_revision_id': fromRevisionId,
      'expected_revision': expectedRevision,
      'reason': reason,
      'request_key': requestKey,
    }, 'rollback_visa_article_response');
    final result = ArticleRevisionResult.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
    if (result.articleId != articleId) {
      throw const CmsException('malformed');
    }
    return result;
  }

  @override
  Future<List<RevisionSummary>> listArticleRevisions({
    required String articleId,
    required String locale,
  }) async {
    final revisions = <RevisionSummary>[];
    String? cursor;
    final visited = <String?>{};
    final identities = <String>{};
    do {
      if (visited.length >= maxPagesPerList || !visited.add(cursor)) {
        throw const CmsException('malformed');
      }
      final response = await _rpc('list_visa_article_revisions', {
        'article_id': articleId,
        'locale': locale,
        'cursor': cursor,
        'limit': 50,
      }, 'list_visa_article_revisions_response');
      final items = (response['data'] as Map)['items'] as List;
      if (items.any(
        (item) =>
            (item as Map)['locale'] != locale ||
            !identities.add(item['revision_id'] as String),
      )) {
        throw const CmsException('malformed');
      }
      revisions.addAll(
        items.map(
          (e) => RevisionSummary.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
      cursor = (response['page'] as Map)['next_cursor'] as String?;
    } while (cursor != null);
    return revisions;
  }

  @override
  Future<List<Authority>> listOfficialAuthorities({
    String? countryCode,
    String? topic,
    String? state,
  }) async {
    final authorities = <Authority>[];
    String? cursor;
    final visited = <String?>{};
    final identities = <String>{};
    do {
      if (visited.length >= maxPagesPerList || !visited.add(cursor)) {
        throw const CmsException('malformed');
      }
      final response = await _rpc('list_official_authorities', {
        'country_code': countryCode,
        'topic': topic,
        'state': state,
        'cursor': cursor,
        'limit': 50,
      }, 'list_official_authorities_response');
      final items = (response['data'] as Map)['items'] as List;
      if (items.any((item) => !identities.add((item as Map)['id'] as String))) {
        throw const CmsException('malformed');
      }
      authorities.addAll(
        items.map(
          (e) => Authority.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
      cursor = (response['page'] as Map)['next_cursor'] as String?;
    } while (cursor != null);
    return authorities;
  }

  @override
  Future<Map<String, dynamic>> discoverOfficialAuthorities({
    required String countryCode,
    required String topic,
    String? profession,
    required String requestKey,
  }) async {
    final response = await _rpc('discover_official_authorities', {
      'country_code': countryCode,
      'topic': topic,
      'profession': profession,
      'request_key': requestKey,
    }, 'discover_official_authorities_response');
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  @override
  Future<Map<String, dynamic>> enqueueResearchRefresh({
    required List<String> authorityIds,
    required String requestKey,
  }) async {
    final response = await _rpc('enqueue_research_refresh', {
      'authority_ids': authorityIds,
      'request_key': requestKey,
    }, 'enqueue_research_refresh_response');
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  @override
  Future<Map<String, dynamic>> approveVisaSourceInventory({
    required String articleId,
    required List<String> sourceSnapshotIds,
    required int expectedInventoryRevision,
    required String requestKey,
  }) async {
    final response = await _rpc('approve_visa_source_inventory', {
      'article_id': articleId,
      'source_snapshot_ids': sourceSnapshotIds,
      'expected_inventory_revision': expectedInventoryRevision,
      'request_key': requestKey,
    }, 'approve_visa_source_inventory_response');
    return Map<String, dynamic>.from(response['data'] as Map);
  }
}

final adminCmsRepositoryProvider = Provider<AdminCmsRepository>((ref) {
  ref.watch(authenticatedUserIdProvider);
  return SupabaseAdminCmsRepository(ref.watch(supabaseClientServiceProvider));
});
