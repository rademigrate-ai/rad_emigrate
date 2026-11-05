import '../../../../core/supabase/supabase_client.dart';
import '../../domain/entities/case_checklist.dart';

/// Server-authoritative checklist snapshot, versioned for stale-edit protection.
class CaseChecklistSnapshot {
  const CaseChecklistSnapshot({required this.items, required this.revision});

  final List<CaseChecklistItem> items;
  final int revision;
}

/// Repository boundary so storage and auth failures are testable without a
/// real Supabase client. Only the authenticated owner can use these RPCs.
abstract class CaseChecklistGateway {
  Future<CaseChecklistSnapshot?> load(String applicationId);

  Future<int> save({
    required String applicationId,
    required List<CaseChecklistItem> items,
    required int expectedRevision,
  });
}

class SupabaseCaseChecklistGateway implements CaseChecklistGateway {
  const SupabaseCaseChecklistGateway(this._backend);

  final SupabaseClientService _backend;

  @override
  Future<CaseChecklistSnapshot?> load(String applicationId) async {
    if (!_backend.isInitialized || _backend.client.auth.currentUser == null) {
      throw StateError('An authenticated session is required.');
    }
    final response = await _backend.client.rpc(
      'get_application_case_checklist',
      params: {'p_application_id': applicationId},
    );
    if (response == null) return null;
    if (response is! Map) {
      throw const FormatException('Invalid checklist response');
    }
    final data = Map<String, dynamic>.from(response);
    final revision = data['revision'];
    final rawItems = data['items'];
    if (revision is! int || revision < 1 || rawItems is! List) {
      throw const FormatException(
        'Invalid persisted checklist revision or items',
      );
    }
    return CaseChecklistSnapshot(
      revision: revision,
      items: rawItems
          .map(
            (item) => CaseChecklistItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<int> save({
    required String applicationId,
    required List<CaseChecklistItem> items,
    required int expectedRevision,
  }) async {
    if (!_backend.isInitialized || _backend.client.auth.currentUser == null) {
      throw StateError('An authenticated session is required.');
    }
    final response = await _backend.client.rpc(
      'put_application_case_checklist',
      params: {
        'p_application_id': applicationId,
        'p_items': items.map((item) => item.toJson()).toList(growable: false),
        'p_expected_revision': expectedRevision,
      },
    );
    if (response is! Map || response['revision'] is! int) {
      throw const FormatException('Checklist persistence was not acknowledged');
    }
    final savedRevision = response['revision'] as int;
    if (savedRevision <= expectedRevision) {
      throw StateError('Checklist revision did not advance');
    }
    return savedRevision;
  }
}
