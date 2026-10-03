import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../data/admin_operations_repository.dart';

class AdminOperationsPage extends ConsumerWidget {
  const AdminOperationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(adminSnapshotProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin operations'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminSnapshotProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: snapshot.when(
        loading: () => const LoadingView(
          message: 'Loading operational data…',
        ),
        error: (error, _) => ErrorView(
          message: 'Admin operations could not be loaded.',
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
    if (!data.canAccess) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This route is restricted to verified RAD administrators.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final metrics = <({String label, int value, IconData icon})>[
      (
        label: 'Applications',
        value: data.applications,
        icon: Icons.assignment_outlined,
      ),
      (
        label: 'Documents',
        value: data.documents,
        icon: Icons.folder_outlined,
      ),
      (
        label: 'Research jobs',
        value: data.researchJobs,
        icon: Icons.travel_explore_outlined,
      ),
      (
        label: 'AI requests',
        value: data.aiRequests,
        icon: Icons.smart_toy_outlined,
      ),
      (
        label: 'Document jobs',
        value: data.documentJobs,
        icon: Icons.document_scanner_outlined,
      ),
      (
        label: 'Open tasks',
        value: data.openTasks,
        icon: Icons.task_alt_outlined,
      ),
      if (data.isSuperAdmin)
        (
          label: 'Audit events',
          value: data.auditEvents,
          icon: Icons.policy_outlined,
        ),
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          data.isSuperAdmin ? 'Super Admin' : 'Admin',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.blue),
        ),
        const SizedBox(height: 8),
        Text(
          'Operational overview',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        for (final metric in metrics)
          _MetricTile(
            label: metric.label,
            value: metric.value,
            icon: metric.icon,
          ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.security_outlined),
            title: Text('Server-enforced access'),
            subtitle: Text(
              'Case notes, tasks, status history, provider health, and role '
              'changes are protected by RLS and audit events.',
            ),
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
        leading: Icon(icon, color: AppColors.blue),
        title: Text(label),
        trailing: Text(
          '$value',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
