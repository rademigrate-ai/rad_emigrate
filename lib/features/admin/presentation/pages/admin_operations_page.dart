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
        loading: () => const LoadingView(message: 'Loading operational data…'),
        error: (error, _) => ErrorView(
          message: 'Admin operations could not be loaded.',
          onRetry: () => ref.invalidate(adminSnapshotProvider),
        ),
        data: (data) {
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
          final metrics = [
            ('Applications', data.applications, Icons.assignment_outlined),
            ('Documents', data.documents, Icons.folder_outlined),
            ('Research jobs', data.researchJobs, Icons.travel_explore_outlined),
            ('AI requests', data.aiRequests, Icons.smart_toy_outlined),
            ('Document jobs', data.documentJobs, Icons.document_scanner_outlined),
            ('Open tasks', data.openTasks, Icons.task_alt_outlined),
            if (data.isSuperAdmin)
              ('Audit events', data.auditEvents, Icons.policy_outlined),
          ];
          return RefreshIndicator(
            onRefresh: () => ref.refresh(adminSnapshotProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  data.isSuperAdmin ? 'Super Admin' : 'Admin',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Operational overview',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900
                        ? 3
                        : constraints.maxWidth >= 560
                        ? 2
                        : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 12) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final metric in metrics)
                          SizedBox(
                            width: width,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Icon(metric.$3, color: AppColors.blue),
                                    const SizedBox(width: 14),
                                    Expanded(child: Text(metric.$1)),
                                    Text(
                                      '${metric.$2}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.security_outlined),
                    title: Text('Server-enforced access'),
                    subtitle: Text(
                      'Case notes, tasks, status history, provider health, and role changes are protected by RLS and audit events.',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
