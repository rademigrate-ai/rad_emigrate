import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/supabase_providers.dart';

class AdminSnapshot {
  const AdminSnapshot({
    required this.role,
    required this.applications,
    required this.documents,
    required this.researchJobs,
    required this.aiRequests,
    required this.documentJobs,
    required this.openTasks,
    required this.auditEvents,
  });

  final String role;
  final int applications;
  final int documents;
  final int researchJobs;
  final int aiRequests;
  final int documentJobs;
  final int openTasks;
  final int auditEvents;

  bool get canAccess => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';
}

class AdminOperationsRepository {
  const AdminOperationsRepository(this._supabase);

  final SupabaseClientService _supabase;

  Future<AdminSnapshot> load() async {
    if (!_supabase.isInitialized) {
      throw StateError('Supabase is not configured.');
    }
    final client = _supabase.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Authentication required.');

    final profile = await client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    final role = profile?['role'] as String? ?? 'user';
    if (role != 'admin' && role != 'super_admin') {
      return AdminSnapshot(
        role: role,
        applications: 0,
        documents: 0,
        researchJobs: 0,
        aiRequests: 0,
        documentJobs: 0,
        openTasks: 0,
        auditEvents: 0,
      );
    }

    Future<int> count(String table, {String? statusColumn}) async {
      var query = client.from(table).select('id');
      if (statusColumn != null) {
        query = query.neq(statusColumn, 'done');
      }
      final rows = await query;
      return rows.length;
    }

    final results = await Future.wait([
      count('applications'),
      count('documents'),
      count('research_jobs'),
      count('ai_requests'),
      count('document_processing_jobs'),
      count('admin_tasks', statusColumn: 'status'),
      if (role == 'super_admin') count('admin_audit_logs') else Future.value(0),
    ]);
    return AdminSnapshot(
      role: role,
      applications: results[0],
      documents: results[1],
      researchJobs: results[2],
      aiRequests: results[3],
      documentJobs: results[4],
      openTasks: results[5],
      auditEvents: results[6],
    );
  }
}

final adminOperationsRepositoryProvider = Provider<AdminOperationsRepository>(
  (ref) => AdminOperationsRepository(ref.watch(supabaseClientServiceProvider)),
);

final adminSnapshotProvider = FutureProvider.autoDispose<AdminSnapshot>(
  (ref) => ref.watch(adminOperationsRepositoryProvider).load(),
);
