import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/rad_contract.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/supabase_providers.dart';
import 'admin_cms_repository.dart';

/// Additive review contract. The server reconstructs from the immutable base;
/// the client never submits a truncated replacement for the complete article.
class ResearchReviewRepository {
  ResearchReviewRepository(this.service)
    : owner = service.isInitialized
          ? service.client.auth.currentUser?.id
          : null;
  final SupabaseClientService service;
  final String? owner;
  final Map<String, String> _keys = {};

  void _checkOwner() {
    if (!service.isInitialized ||
        owner == null ||
        service.client.auth.currentUser?.id != owner) {
      throw const CmsException('unauthorized');
    }
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> params,
  ) async {
    _checkOwner();
    dynamic response;
    try {
      response = await service.client
          .rpc(name, params: params)
          .timeout(const Duration(seconds: 30));
    } on PostgrestException catch (error) {
      _checkOwner();
      throw CmsException(switch (error.code) {
        'PT401' || 'PT403' || '42501' => 'unauthorized',
        'PT409' => 'conflict',
        'PT422' when error.message == 'rich_body_reconciliation_required' =>
          'rich_reconciliation',
        'PT422' => 'invalid_review',
        _ => 'unavailable',
      });
    }
    _checkOwner();
    if (response is! Map || response['data'] is! Map) {
      throw const CmsException('malformed');
    }
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  Future<Map<String, dynamic>> context(String proposalId) async {
    final data = await _call('get_research_review_context', {
      'p_proposal_id': proposalId,
    });
    final base = data['base'];
    final proposal = data['proposal'];
    if (proposal is! Map ||
        proposal['id'] != proposalId ||
        base is! Map ||
        base['body'] is! Map ||
        base['body']['sections'] is! List ||
        base['content_hash'] is! String ||
        base['revision_id'] is! String ||
        data['review_revision'] is! int ||
        data['stale'] is! bool ||
        data['decisions'] is! List) {
      throw const CmsException('malformed');
    }
    return data;
  }

  Future<Map<String, dynamic>> save({
    required Map<String, dynamic> context,
    required String mode,
    required Map<String, String> decisions,
    required Map<String, String> edits,
    required String note,
  }) {
    final base = context['base'] as Map;
    final proposal = context['proposal'] as Map;
    final ids = decisions.keys.toList()..sort();
    final request = <String, dynamic>{
      'proposal_id': proposal['id'],
      'expected_proposal_revision': proposal['revision'],
      'expected_review_revision': context['review_revision'],
      'base_revision_id': base['revision_id'],
      'base_content_hash': base['content_hash'],
      'mode': mode,
      'decisions': [
        for (final id in ids)
          {
            'section_id': id,
            'decision': decisions[id] == 'accepted'
                ? (edits.containsKey(id) ? 'edit' : 'accept')
                : 'reject',
            'edited_text': decisions[id] == 'accepted' ? edits[id] : null,
          },
      ],
      'note': note,
    };
    final fingerprint = jsonEncode(request);
    request['request_key'] = _keys.putIfAbsent(fingerprint, newRadRequestKey);
    return _call('save_research_review', {'p_request': request});
  }
}

final researchReviewRepositoryProvider = Provider<ResearchReviewRepository>((
  ref,
) {
  ref.watch(supabaseAuthUserIdProvider);
  return ResearchReviewRepository(ref.watch(supabaseClientServiceProvider));
});
