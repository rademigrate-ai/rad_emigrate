import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/admin_operations_repository.dart';
import 'admin_review_detail_sheet.dart';

part 'admin_operations_sections.dart';

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
        loading: () => LoadingState(message: l10n.loadingOperational),
        error: (error, _) => ErrorState(
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
            loading: () => LoadingState(message: l10n.loadingOperational),
            error: (error, _) => ErrorState(
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
            _KeyValue(l10n.providersLabel, '${data.providers.length}'),
            _KeyValue(l10n.modelsLabel, '${data.models.length}'),
            _KeyValue(l10n.reviewQueueTitle, '${data.reviews.length}'),
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
