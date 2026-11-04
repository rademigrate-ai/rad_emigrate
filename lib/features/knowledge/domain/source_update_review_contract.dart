import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Phase 2 preparation only: no writes, no CMS approval, no Feed publication.
/// A research agent may extract evidence; an authenticated human reviewer must
/// later approve a server-bound CMS revision from the real editorial workflow.
class SourceUpdateReviewContract {
  static Map<String, dynamic> prepare({
    required Map<String, dynamic> immutableBaseline,
    required String blockId,
    required String expectedOldText,
    required String sourceUrl,
    required String newCapturedBody,
    required String capturedBodySha256,
    required String literalReplacement,
    required String capturedAt,
  }) {
    if (immutableBaseline['delivery_mode'] != 'frozen_source_readonly' ||
        immutableBaseline['editorial_approved'] != false ||
        immutableBaseline['source_policy'] != 'RAD_CONTENT_PRECEDENCE_V4.1' ||
        immutableBaseline['id'] is! String ||
        immutableBaseline['revision_id'] is! String ||
        immutableBaseline['source_payload_sha256'] is! String) {
      throw const FormatException('immutable_source_baseline_required');
    }
    final sources = immutableBaseline['sources'];
    if (sources is! List ||
        !sources.whereType<Map>().any((s) => s['url'] == sourceUrl)) {
      throw const FormatException('bound_original_source_required');
    }
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        !{
          'digivisa.ir',
          'radvisa.com',
          'radmohajer.ir',
        }.contains(uri.host.replaceFirst('www.', '').toLowerCase())) {
      throw const FormatException('authenticated_primary_source_required');
    }
    if (capturedBodySha256.length != 64 ||
        sha256.convert(utf8.encode(newCapturedBody)).toString() !=
            capturedBodySha256) {
      throw const FormatException('new_capture_hash_mismatch');
    }
    if (DateTime.tryParse(capturedAt) == null ||
        newCapturedBody.trim().isEmpty ||
        literalReplacement.trim().isEmpty ||
        !newCapturedBody.contains(literalReplacement) ||
        expectedOldText.trim().isEmpty ||
        expectedOldText == literalReplacement) {
      throw const FormatException('literal_change_capture_required');
    }
    final sections = immutableBaseline['rich_sections'];
    if (sections is! List) {
      throw const FormatException('full_baseline_body_required');
    }
    var matches = 0;
    for (final section in sections.whereType<Map>()) {
      for (final block in (section['blocks'] as List? ?? []).whereType<Map>()) {
        final structure = block['original_structure'];
        final actual = structure is Map ? structure['text'] : block['text'];
        if (block['id'] == blockId) {
          matches++;
          if (actual != expectedOldText) {
            throw const FormatException('baseline_block_content_drift');
          }
        }
      }
    }
    if (matches != 1) {
      throw const FormatException('unique_unchanged_source_block_required');
    }
    return {
      'kind': 'RAD_SOURCE_UPDATE_REVIEW_CANDIDATE_V1',
      'article_id': immutableBaseline['id'],
      'locale': immutableBaseline['locale'],
      'base_revision_id': immutableBaseline['revision_id'],
      'base_payload_sha256': immutableBaseline['source_payload_sha256'],
      'block_id': blockId,
      'expected_old_text': expectedOldText,
      'literal_new_text': literalReplacement,
      'original_source_url': sourceUrl,
      'new_capture_sha256': capturedBodySha256,
      'captured_at': capturedAt,
      'status': 'local_review_candidate_only',
      'requires_authenticated_editorial_admin': true,
      'must_revalidate_against_live_cms_revision': true,
      'can_write_frozen_snapshot': false,
      'approved': false,
      'can_publish': false,
      'can_auto_publish_feed': false,
    };
  }
}
