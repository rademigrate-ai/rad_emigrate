import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/admin_operations_repository.dart';

class AdminOperationsPage extends ConsumerWidget {
  const AdminOperationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final snapshot = ref.watch(adminSnapshotProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminOperations),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () => ref.invalidate(adminSnapshotProvider),
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
        data: (data) => _AdminOverview(data: data),
      ),
    );
  }
}

class _AdminOverview extends StatelessWidget {
  const _AdminOverview({required this.data});

  final AdminSnapshot data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!data.canAccess) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.adminRestricted,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final metrics = <({String label, int value, IconData icon})>[
      (
        label: l10n.applications,
        value: data.applications,
        icon: Icons.assignment_outlined,
      ),
      (
        label: l10n.documents,
        value: data.documents,
        icon: Icons.folder_outlined,
      ),
      (
        label: l10n.researchJobs,
        value: data.researchJobs,
        icon: Icons.travel_explore_outlined,
      ),
      (
        label: l10n.aiRequests,
        value: data.aiRequests,
        icon: Icons.smart_toy_outlined,
      ),
      (
        label: l10n.documentJobs,
        value: data.documentJobs,
        icon: Icons.document_scanner_outlined,
      ),
      (
        label: l10n.openTasks,
        value: data.openTasks,
        icon: Icons.task_alt_outlined,
      ),
      if (data.isSuperAdmin)
        (
          label: l10n.auditEvents,
          value: data.auditEvents,
          icon: Icons.policy_outlined,
        ),
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          data.isSuperAdmin ? l10n.superAdmin : l10n.admin,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: AppColors.info),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.operationalOverview,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        for (final metric in metrics)
          _MetricTile(
            label: metric.label,
            value: metric.value,
            icon: metric.icon,
          ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.security_outlined),
            title: Text(l10n.serverEnforcedAccess),
            subtitle: Text(l10n.serverEnforcedAccessBody),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.info),
        title: Text(label),
        trailing: Text(
          '$value',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
