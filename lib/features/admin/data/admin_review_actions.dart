import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/supabase_providers.dart';
import 'review_snapshot_provenance.dart';

/// Stage 2 editorial actions: reject / keep / approve / explicit publish.
/// Server-side RPCs enforce admin/super_admin; Flutter never auto-publishes.
class AdminReviewActions {
  const AdminReviewActions(this._supabase);

  final SupabaseClientService _supabase;

  Future<void> setDraftStatus({
    required String draftId,
    required String status,
  }) async {
    await _supabase.client.rpc(
      'set_content_draft_status',
      params: {'p_draft_id': draftId, 'p_status': status},
    );
  }

  Future<void> updateDraft({
    required String draftId,
    required String title,
    required String body,
    String? languageCode,
    String? category,
  }) async {
    await _supabase.client.rpc(
      'update_content_draft',
      params: {
        'p_draft_id': draftId,
        'p_title': title,
        'p_body': body,
        'p_language_code': languageCode,
        'p_category': category,
      },
    );
  }

  /// Explicit human publish. Idempotent on the server.
  Future<String> publishDraft({
    required String draftId,
    String category = 'update',
    String? slug,
  }) async {
    final result = await _supabase.client.rpc(
      'publish_content_draft',
      params: {'p_draft_id': draftId, 'p_category': category, 'p_slug': slug},
    );
    return result as String;
  }

  Future<void> setFindingStatus({
    required String findingId,
    required String status,
  }) async {
    await _supabase.client.rpc(
      'set_research_finding_status',
      params: {'p_finding_id': findingId, 'p_status': status},
    );
  }

  /// Loads a single draft with enough context for editorial decision.
  Future<Map<String, dynamic>?> loadDraftDetail(String draftId) async {
    if (!_supabase.isInitialized) return null;
    final row = await _supabase.client
        .from('content_drafts')
        .select(
          'id,title,body,status,language_code,category,source_url,'
          'primary_source_id,research_job_id,research_finding_id,feed_item_id,created_at,updated_at,'
          'content_sources:primary_source_id(title,url,publisher,source_type)',
        )
        .eq('id', draftId)
        .maybeSingle();
    if (row == null) return null;

    // The production finding→draft pipeline preserves snapshot provenance,
    // but legacy drafts can have no source_url / content source FK.
    // Reconstruct the source reference for the human reviewer, without
    // modifying the draft, approving claims, or publishing anything.
    final findingId = row['research_finding_id'];
    if (findingId == null ||
        (row['source_url'] is String &&
            (row['source_url'] as String).trim().isNotEmpty)) {
      return row;
    }

    try {
      final finding = await _supabase.client
          .from('research_findings')
          .select('snapshot_id')
          .eq('id', findingId)
          .maybeSingle();
      final snapshotId = finding?['snapshot_id'];
      if (snapshotId == null) return row;

      final snapshot = await _supabase.client
          .from('source_snapshots')
          .select('document_id,http_status')
          .eq('id', snapshotId)
          .maybeSingle();
      final documentId = snapshot?['document_id'];
      if (documentId == null) return row;

      final document = await _supabase.client
          .from('source_documents')
          .select('canonical_url,removed_at,source_authority')
          .eq('id', documentId)
          .maybeSingle();

      final sourceUrl = verifiedReviewSnapshotUrl(
        canonicalUrl: document?['canonical_url'],
        httpStatus: snapshot?['http_status'],
        removedAt: document?['removed_at'],
      );
      if (sourceUrl == null) return row;
      return {
        ...row,
        'source_url': sourceUrl,
        'source_url_from_snapshot': true,
        'source_authority': document?['source_authority'],
      };
    } catch (_) {
      // Provenance failure must never be mistaken for verified source.
      // Preserve normal draft review/editing; the link stays absent.
      return {...row, 'source_verification_unavailable': true};
    }
  }
}

final adminReviewActionsProvider = Provider<AdminReviewActions>(
  (ref) => AdminReviewActions(ref.watch(supabaseClientServiceProvider)),
);
