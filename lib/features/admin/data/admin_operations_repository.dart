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

class AdminProviderRecord {
  const AdminProviderRecord({
    required this.id,
    required this.slug,
    required this.displayName,
    required this.adapter,
    required this.baseUrl,
    required this.enabled,
    required this.priority,
    required this.credentialConfigured,
    required this.healthStatus,
    required this.lastSuccessAt,
    required this.lastFailureAt,
  });

  final String id;
  final String slug;
  final String displayName;
  final String adapter;
  final String baseUrl;
  final bool enabled;
  final int priority;
  final bool credentialConfigured;
  final String healthStatus;
  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;
}

class AdminModelRecord {
  const AdminModelRecord({
    required this.id,
    required this.providerId,
    required this.slug,
    required this.displayName,
    required this.capability,
    required this.enabled,
    required this.maxOutputTokens,
  });

  final String id;
  final String providerId;
  final String slug;
  final String displayName;
  final String capability;
  final bool enabled;
  final int maxOutputTokens;
}

class AdminSourceRecord {
  const AdminSourceRecord({
    required this.id,
    required this.title,
    required this.publisher,
    required this.url,
    required this.sourceType,
    required this.languageCode,
    required this.active,
    required this.retrievedAt,
  });

  final String id;
  final String title;
  final String publisher;
  final String url;
  final String sourceType;
  final String languageCode;
  final bool active;
  final DateTime? retrievedAt;
}

class AdminResearchSourceRecord {
  const AdminResearchSourceRecord({
    required this.id,
    required this.baseUrl,
    required this.allowedHost,
    required this.authority,
    required this.enabled,
    required this.lastAttemptAt,
    required this.lastSuccessAt,
  });

  final String id;
  final String baseUrl;
  final String allowedHost;
  final String authority;
  final bool enabled;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;
}

class AdminResearchJobRecord {
  const AdminResearchJobRecord({
    required this.id,
    required this.jobType,
    required this.status,
    required this.triggerType,
    required this.createdAt,
    required this.safeError,
  });

  final String id;
  final String jobType;
  final String status;
  final String triggerType;
  final DateTime? createdAt;
  final String? safeError;
}

class AdminReviewRecord {
  const AdminReviewRecord({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.summary,
  });

  final String id;
  final String kind;
  final String title;
  final String status;
  final DateTime? createdAt;
  final String? summary;
}

class AdminFeedRecord {
  const AdminFeedRecord({
    required this.id,
    required this.slug,
    required this.category,
    required this.status,
    required this.publishedAt,
  });

  final String id;
  final String slug;
  final String category;
  final String status;
  final DateTime? publishedAt;
}

class AdminHealthRecord {
  const AdminHealthRecord({
    required this.slug,
    required this.displayName,
    required this.enabled,
    required this.critical,
  });

  final String slug;
  final String displayName;
  final bool enabled;
  final bool critical;
}

class AdminAuditRecord {
  const AdminAuditRecord({
    required this.id,
    required this.action,
    required this.resourceType,
    required this.resourceId,
    required this.createdAt,
  });

  final String id;
  final String action;
  final String resourceType;
  final String? resourceId;
  final DateTime? createdAt;
}

class AdminConsoleData {
  const AdminConsoleData({
    required this.providers,
    required this.models,
    required this.sources,
    required this.researchSources,
    required this.researchJobs,
    required this.reviews,
    required this.feedItems,
    required this.health,
    required this.audit,
  });

  final List<AdminProviderRecord> providers;
  final List<AdminModelRecord> models;
  final List<AdminSourceRecord> sources;
  final List<AdminResearchSourceRecord> researchSources;
  final List<AdminResearchJobRecord> researchJobs;
  final List<AdminReviewRecord> reviews;
  final List<AdminFeedRecord> feedItems;
  final List<AdminHealthRecord> health;
  final List<AdminAuditRecord> audit;
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

class AdminOperationsRepository {
  const AdminOperationsRepository(this._supabase);

  final SupabaseClientService _supabase;

  Future<String> _role() async {
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
    return profile?['role'] as String? ?? 'user';
  }

  Future<AdminSnapshot> load() async {
    final role = await _role();
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
    final client = _supabase.client;

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

  Future<AdminConsoleData> loadConsole() async {
    final role = await _role();
    if (role != 'admin' && role != 'super_admin') {
      throw StateError('Administrator access required.');
    }
    final client = _supabase.client;
    final providersFuture = client
        .from('ai_providers')
        .select(
          'id,slug,display_name,adapter,base_url,secret_id,enabled,priority,'
          'ai_provider_health(status,last_success_at,last_failure_at)',
        )
        .order('priority');
    final modelsFuture = client
        .from('ai_models')
        .select(
          'id,provider_id,slug,display_name,capability,enabled,max_output_tokens',
        )
        .order('display_name');
    final sourcesFuture = client
        .from('content_sources')
        .select(
          'id,title,publisher,url,source_type,language_code,is_active,retrieved_at',
        )
        .order('source_type')
        .order('publisher');
    final researchSourcesFuture = client
        .from('research_sources')
        .select(
          'id,base_url,allowed_host,authority,enabled,last_attempt_at,last_success_at',
        )
        .order('authority');
    final researchJobsFuture = client
        .from('research_jobs')
        .select('id,job_type,status,trigger_type,created_at,safe_error')
        .order('created_at', ascending: false)
        .limit(25);
    final findingsFuture = client
        .from('research_findings')
        .select('id,summary,review_status,created_at')
        .neq('review_status', 'approved')
        .order('created_at', ascending: false)
        .limit(25);
    final draftsFuture = client
        .from('content_drafts')
        .select('id,title,status,created_at')
        .neq('status', 'published')
        .order('created_at', ascending: false)
        .limit(25);
    final feedFuture = client
        .from('feed_items')
        .select('id,slug,category,status,published_at')
        .order('updated_at', ascending: false)
        .limit(25);
    final healthFuture = client
        .from('system_components')
        .select('slug,display_name,enabled,critical')
        .order('display_name');
    final auditFuture = role == 'super_admin'
        ? client
              .from('admin_audit_logs')
              .select('id,action,resource_type,resource_id,created_at')
              .order('created_at', ascending: false)
              .limit(25)
        : Future.value(<Map<String, dynamic>>[]);

    final results = await Future.wait<Object>([
      providersFuture,
      modelsFuture,
      sourcesFuture,
      researchSourcesFuture,
      researchJobsFuture,
      findingsFuture,
      draftsFuture,
      feedFuture,
      healthFuture,
      auditFuture,
    ]);
    List<Map<String, dynamic>> rows(int index) =>
        (results[index] as List).cast<Map<String, dynamic>>();

    final reviews = <AdminReviewRecord>[
      ...rows(5).map(
        (row) => AdminReviewRecord(
          id: row['id'] as String,
          kind: 'finding',
          title: row['summary'] as String? ?? '',
          summary: row['summary'] as String?,
          status: row['review_status'] as String? ?? 'review',
          createdAt: _date(row['created_at']),
        ),
      ),
      ...rows(6).map(
        (row) => AdminReviewRecord(
          id: row['id'] as String,
          kind: 'draft',
          title: row['title'] as String? ?? '',
          summary: null,
          status: row['status'] as String? ?? 'draft',
          createdAt: _date(row['created_at']),
        ),
      ),
    ]..sort((a, b) {
        final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });

    return AdminConsoleData(
      providers: rows(0).map((row) {
        final relation = row['ai_provider_health'];
        Map<String, dynamic>? health;
        if (relation is List && relation.isNotEmpty) {
          health = (relation.first as Map).cast<String, dynamic>();
        } else if (relation is Map) {
          health = relation.cast<String, dynamic>();
        }
        return AdminProviderRecord(
          id: row['id'] as String,
          slug: row['slug'] as String,
          displayName: row['display_name'] as String,
          adapter: row['adapter'] as String,
          baseUrl: row['base_url'] as String,
          enabled: row['enabled'] as bool? ?? false,
          priority: row['priority'] as int? ?? 100,
          credentialConfigured: row['secret_id'] != null,
          healthStatus: health?['status'] as String? ?? 'unknown',
          lastSuccessAt: _date(health?['last_success_at']),
          lastFailureAt: _date(health?['last_failure_at']),
        );
      }).toList(),
      models: rows(1)
          .map(
            (row) => AdminModelRecord(
              id: row['id'] as String,
              providerId: row['provider_id'] as String,
              slug: row['slug'] as String,
              displayName: row['display_name'] as String,
              capability: row['capability'] as String,
              enabled: row['enabled'] as bool? ?? false,
              maxOutputTokens: row['max_output_tokens'] as int? ?? 2048,
            ),
          )
          .toList(),
      sources: rows(2)
          .map(
            (row) => AdminSourceRecord(
              id: row['id'] as String,
              title: row['title'] as String,
              publisher: row['publisher'] as String,
              url: row['url'] as String,
              sourceType: row['source_type'] as String,
              languageCode: row['language_code'] as String,
              active: row['is_active'] as bool? ?? false,
              retrievedAt: _date(row['retrieved_at']),
            ),
          )
          .toList(),
      researchSources: rows(3)
          .map(
            (row) => AdminResearchSourceRecord(
              id: row['id'] as String,
              baseUrl: row['base_url'] as String,
              allowedHost: row['allowed_host'] as String,
              authority: row['authority'] as String,
              enabled: row['enabled'] as bool? ?? false,
              lastAttemptAt: _date(row['last_attempt_at']),
              lastSuccessAt: _date(row['last_success_at']),
            ),
          )
          .toList(),
      researchJobs: rows(4)
          .map(
            (row) => AdminResearchJobRecord(
              id: row['id'] as String,
              jobType: row['job_type'] as String,
              status: row['status'] as String,
              triggerType: row['trigger_type'] as String,
              createdAt: _date(row['created_at']),
              safeError: row['safe_error'] as String?,
            ),
          )
          .toList(),
      reviews: reviews,
      feedItems: rows(7)
          .map(
            (row) => AdminFeedRecord(
              id: row['id'] as String,
              slug: row['slug'] as String,
              category: row['category'] as String,
              status: row['status'] as String,
              publishedAt: _date(row['published_at']),
            ),
          )
          .toList(),
      health: rows(8)
          .map(
            (row) => AdminHealthRecord(
              slug: row['slug'] as String,
              displayName: row['display_name'] as String,
              enabled: row['enabled'] as bool? ?? false,
              critical: row['critical'] as bool? ?? false,
            ),
          )
          .toList(),
      audit: rows(9)
          .map(
            (row) => AdminAuditRecord(
              id: '${row['id']}',
              action: row['action'] as String,
              resourceType: row['resource_type'] as String,
              resourceId: row['resource_id'] as String?,
              createdAt: _date(row['created_at']),
            ),
          )
          .toList(),
    );
  }
}

final adminOperationsRepositoryProvider = Provider<AdminOperationsRepository>(
  (ref) => AdminOperationsRepository(ref.watch(supabaseClientServiceProvider)),
);

final adminSnapshotProvider = FutureProvider.autoDispose<AdminSnapshot>(
  (ref) => ref.watch(adminOperationsRepositoryProvider).load(),
);

final adminConsoleProvider = FutureProvider.autoDispose<AdminConsoleData>(
  (ref) => ref.watch(adminOperationsRepositoryProvider).loadConsole(),
);
