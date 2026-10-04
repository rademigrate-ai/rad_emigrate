import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/admin_operations_repository.dart';

class AdminOperationsPage extends ConsumerStatefulWidget {
  const AdminOperationsPage({super.key});

  @override
  ConsumerState<AdminOperationsPage> createState() =>
      _AdminOperationsPageState();
}

class _AdminOperationsPageState extends ConsumerState<AdminOperationsPage> {
  var _section = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snapshot = ref.watch(adminSnapshotProvider);
    final console = ref.watch(adminConsoleProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminOperations),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () {
              ref.invalidate(adminSnapshotProvider);
              ref.invalidate(adminConsoleProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: snapshot.when(
        loading: () => LoadingView(message: l10n.loadingOperational),
        error: (error, _) => ErrorView(
          message: l10n.adminLoadFailed,
          onRetry: () => ref.invalidate(adminSnapshotProvider),
        ),
        data: (summary) {
          if (!summary.canAccess) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.adminRestricted, textAlign: TextAlign.center),
              ),
            );
          }
          return console.when(
            loading: () => LoadingView(message: l10n.loadingOperational),
            error: (error, _) => ErrorView(
              message: l10n.adminLoadFailed,
              onRetry: () => ref.invalidate(adminConsoleProvider),
            ),
            data: (data) => _AdminConsole(
              summary: summary,
              data: data,
              section: _section,
              onSectionChanged: (value) => setState(() => _section = value),
            ),
          );
        },
      ),
    );
  }
}

class _AdminConsole extends StatelessWidget {
  const _AdminConsole({
    required this.summary,
    required this.data,
    required this.section,
    required this.onSectionChanged,
  });

  final AdminSnapshot summary;
  final AdminConsoleData data;
  final int section;
  final ValueChanged<int> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1100;
    final sections = <({String label, IconData icon})>[
      (label: l10n.operationalOverview, icon: Icons.dashboard_outlined),
      (label: l10n.aiRequests, icon: Icons.smart_toy_outlined),
      (label: l10n.source, icon: Icons.source_outlined),
      (label: l10n.researchJobs, icon: Icons.travel_explore_outlined),
      (label: l10n.statusReviewing, icon: Icons.fact_check_outlined),
      (label: l10n.feed, icon: Icons.newspaper_outlined),
      (label: l10n.serverEnforcedAccess, icon: Icons.monitor_heart_outlined),
      if (summary.isSuperAdmin)
        (label: l10n.auditEvents, icon: Icons.policy_outlined),
    ];
    final safeSection = section.clamp(0, sections.length - 1);
    final content = switch (safeSection) {
      0 => _Overview(summary: summary, data: data),
      1 => _Providers(data: data),
      2 => _Sources(data: data),
      3 => _Research(data: data),
      4 => _Reviews(data: data),
      5 => _Feed(data: data),
      6 => _Health(data: data),
      _ => _Audit(data: data),
    };
    return SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (desktop)
            SizedBox(
              width: 250,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 8, 24),
                children: [
                  Text(
                    summary.isSuperAdmin ? l10n.superAdmin : l10n.admin,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var index = 0; index < sections.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        selected: safeSection == index,
                        leading: Icon(sections[index].icon),
                        title: Text(sections[index].label),
                        onTap: () => onSectionChanged(index),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Column(
              children: [
                if (!desktop)
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: sections.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) => ChoiceChip(
                        avatar: Icon(sections[index].icon, size: 18),
                        label: Text(sections[index].label),
                        selected: safeSection == index,
                        onSelected: (_) => onSectionChanged(index),
                      ),
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: content,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.summary, required this.data});

  final AdminSnapshot summary;
  final AdminConsoleData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metrics = <({String label, int value, IconData icon})>[
      (
        label: l10n.applications,
        value: summary.applications,
        icon: Icons.assignment_outlined,
      ),
      (
        label: l10n.documents,
        value: summary.documents,
        icon: Icons.folder_outlined,
      ),
      (
        label: l10n.researchJobs,
        value: summary.researchJobs,
        icon: Icons.travel_explore_outlined,
      ),
      (
        label: l10n.aiRequests,
        value: summary.aiRequests,
        icon: Icons.smart_toy_outlined,
      ),
      (
        label: l10n.documentJobs,
        value: summary.documentJobs,
        icon: Icons.document_scanner_outlined,
      ),
      (
        label: l10n.openTasks,
        value: summary.openTasks,
        icon: Icons.task_alt_outlined,
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          l10n.operationalOverview,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            final ratio = columns == 1 ? 4.2 : 2.5;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: ratio,
              ),
              itemCount: metrics.length,
              itemBuilder: (context, index) =>
                  _MetricCard(metric: metrics[index]),
            );
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.security_outlined),
            title: Text(l10n.serverEnforcedAccess),
            subtitle: Text(l10n.serverEnforcedAccessBody),
          ),
        ),
        const SizedBox(height: 12),
        _DataSummaryCard(
          icon: Icons.hub_outlined,
          title: l10n.aiRequests,
          rows: [
            _KeyValue('Providers', '${data.providers.length}'),
            _KeyValue('Models', '${data.models.length}'),
            _KeyValue('Review queue', '${data.reviews.length}'),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final ({String label, int value, IconData icon}) metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(metric.icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(metric.label)),
            Text(
              '${metric.value}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Providers extends StatelessWidget {
  const _Providers({required this.data});

  final AdminConsoleData data;

  @override
  Widget build(BuildContext context) {
    return _SectionList(
      title: 'AI Configuration · Providers & Models',
      emptyTitle: 'No AI provider is configured yet.',
      emptySubtitle: 'Provider credentials remain server-side. Existing secrets are never displayed.',
      children: [
        for (final provider in data.providers)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          provider.displayName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _StatusBadge(
                        '${provider.healthStatus} · ${provider.enabled ? 'enabled' : 'disabled'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _LtrValue('${provider.adapter} · ${provider.baseUrl}'),
                  const SizedBox(height: 8),
                  Text(
                    'Credential: ${provider.credentialConfigured ? 'Configured' : 'Not configured'} · Priority ${provider.priority}',
                  ),
                  const SizedBox(height: 12),
                  Text('Models', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  if (data.models
                      .where((item) => item.providerId == provider.id)
                      .isEmpty)
                    const Text('No models registered.')
                  else
                    ...data.models
                        .where((item) => item.providerId == provider.id)
                        .map(
                          (model) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: Icon(
                              model.enabled
                                  ? Icons.check_circle_outline
                                  : Icons.pause_circle_outline,
                            ),
                            title: Text(model.displayName),
                            subtitle: _LtrValue(
                              '${model.slug} · ${model.capability}',
                            ),
                            trailing: Text('${model.maxOutputTokens}'),
                          ),
                        ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Sources extends StatelessWidget {
  const _Sources({required this.data});

  final AdminConsoleData data;

  @override
  Widget build(BuildContext context) {
    return _SectionList(
      title: 'Sources',
      emptyTitle: 'No content sources are configured.',
      emptySubtitle: 'RAD official sources and approved authoritative sources appear here.',
      children: [
        for (final source in data.sources)
          Card(
            child: ListTile(
              leading: Icon(
                source.active
                    ? Icons.verified_outlined
                    : Icons.pause_circle_outline,
              ),
              title: Text(source.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${source.publisher} · ${source.sourceType} · ${source.languageCode.toUpperCase()}',
                  ),
                  _LtrValue(source.url),
                ],
              ),
              trailing: _StatusBadge(source.active ? 'active' : 'inactive'),
            ),
          ),
        if (data.researchSources.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Research allowlist',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final source in data.researchSources)
            Card(
              child: ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: _LtrValue(source.allowedHost),
                subtitle: _LtrValue(source.baseUrl),
                trailing: _StatusBadge(
                  source.enabled ? source.authority : 'disabled',
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Research extends StatelessWidget {
  const _Research({required this.data});

  final AdminConsoleData data;

  @override
  Widget build(BuildContext context) {
    return _SectionList(
      title: 'Research',
      emptyTitle: 'No research jobs yet.',
      emptySubtitle: 'Research discovers and compares evidence, but never publishes automatically.',
      children: [
        for (final job in data.researchJobs)
          Card(
            child: ListTile(
              leading: const Icon(Icons.travel_explore_outlined),
              title: Text(job.jobType.replaceAll('_', ' ')),
              subtitle: Text(
                job.safeError == null
                    ? job.triggerType
                    : 'Safe error: ${job.safeError}',
              ),
              trailing: _StatusBadge(job.status),
            ),
          ),
      ],
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.data});

  final AdminConsoleData data;

  @override
  Widget build(BuildContext context) {
    return _SectionList(
      title: 'Review queue',
      emptyTitle: 'Nothing is waiting for review.',
      emptySubtitle: 'Research findings and editorial drafts appear here before any publication decision.',
      children: [
        for (final item in data.reviews)
          Card(
            child: ListTile(
              leading: Icon(
                item.kind == 'finding'
                    ? Icons.find_in_page_outlined
                    : Icons.edit_note_outlined,
              ),
              title: Text(item.title),
              subtitle: Text(
                item.kind == 'finding' ? 'Research finding' : 'Editorial draft',
              ),
              trailing: _StatusBadge(item.status),
            ),
          ),
      ],
    );
  }
}

class _Feed extends StatelessWidget {
  const _Feed({required this.data});

  final AdminConsoleData data;

  @override
  Widget build(BuildContext context) {
    return _SectionList(
      title: 'Feed / Publishing',
      emptyTitle: 'No Feed items yet.',
      emptySubtitle:
          'Publishing is a deliberate human-admin action after review.',
      children: [
        for (final item in data.feedItems)
          Card(
            child: ListTile(
              leading: const Icon(Icons.newspaper_outlined),
              title: _LtrValue(item.slug),
              subtitle: Text(item.category),
              trailing: _StatusBadge(item.status),
            ),
          ),
      ],
    );
  }
}

class _Health extends StatelessWidget {
  const _Health({required this.data});

  final AdminConsoleData data;

  @override
  Widget build(BuildContext context) {
    return _SectionList(
      title: 'Operations / Health',
      emptyTitle: 'No operational components are registered.',
      emptySubtitle: 'Component inventory is unavailable.',
      children: [
        for (final item in data.health)
          Card(
            child: ListTile(
              leading: Icon(
                item.enabled
                    ? Icons.monitor_heart_outlined
                    : Icons.pause_circle_outline,
              ),
              title: Text(item.displayName),
              subtitle: _LtrValue(item.slug),
              trailing: _StatusBadge(
                '${item.enabled ? 'enabled' : 'disabled'}${item.critical ? ' · critical' : ''}',
              ),
            ),
          ),
      ],
    );
  }
}

class _Audit extends StatelessWidget {
  const _Audit({required this.data});

  final AdminConsoleData data;

  @override
  Widget build(BuildContext context) {
    return _SectionList(
      title: 'Audit / Security',
      emptyTitle: 'No audit events are visible.',
      emptySubtitle: 'Audit history is restricted to Super Admin.',
      children: [
        for (final item in data.audit)
          Card(
            child: ListTile(
              leading: const Icon(Icons.policy_outlined),
              title: Text(item.action),
              subtitle: Text(
                '${item.resourceType}${item.resourceId == null ? '' : ' · ${item.resourceId}'}',
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({
    required this.title,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.children,
  });

  final String title;
  final String emptyTitle;
  final String emptySubtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        if (children.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emptyTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(emptySubtitle),
                ],
              ),
            ),
          )
        else
          ...children,
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _LtrValue extends StatelessWidget {
  const _LtrValue(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Text(value, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _KeyValue {
  const _KeyValue(this.label, this.value);

  final String label;
  final String value;
}

class _DataSummaryCard extends StatelessWidget {
  const _DataSummaryCard({
    required this.icon,
    required this.title,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final List<_KeyValue> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(row.label)),
                    Text(row.value),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
