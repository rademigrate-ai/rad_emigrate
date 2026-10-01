import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../domain/entities/application_status.dart';
import '../../domain/entities/visa_application.dart';
import '../providers/application_controller.dart';

class ApplicationsPage extends ConsumerStatefulWidget {
  const ApplicationsPage({super.key});

  @override
  ConsumerState<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends ConsumerState<ApplicationsPage> {
  VisaApplication? _selected;

  Color _statusColor(ApplicationStatus s) {
    switch (s) {
      case ApplicationStatus.draft:
        return Colors.grey;
      case ApplicationStatus.submitted:
        return Colors.blue;
      case ApplicationStatus.reviewing:
      case ApplicationStatus.documentsRequired:
        return Colors.orange;
      case ApplicationStatus.approved:
      case ApplicationStatus.completed:
        return Colors.green;
      case ApplicationStatus.rejected:
        return AppColors.primaryRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(applicationControllerProvider);

    if (_selected != null) {
      final app = _selected!;
      return Scaffold(
        appBar: AppBar(
          title: Text(app.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _selected = null),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(title: const Text('Program'), subtitle: Text(app.programName)),
            ListTile(title: const Text('Country'), subtitle: Text(app.country)),
            ListTile(
              title: const Text('Status'),
              subtitle: Text(app.status.label),
              trailing: Chip(
                label: Text(
                  app.status.label,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: _statusColor(app.status),
              ),
            ),
            ListTile(
              title: const Text('Last updated'),
              subtitle: Text(
                '${app.updatedAt.year}-${app.updatedAt.month.toString().padLeft(2, '0')}-${app.updatedAt.day.toString().padLeft(2, '0')}',
              ),
            ),
            if (app.notes != null)
              ListTile(title: const Text('Notes'), subtitle: Text(app.notes!)),
            const SizedBox(height: 16),
            Text('Update status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ApplicationStatus.values.map((s) {
                return FilterChip(
                  label: Text(s.label),
                  selected: app.status == s,
                  onSelected: (_) async {
                    await ref
                        .read(applicationControllerProvider.notifier)
                        .updateStatus(app.id, s);
                    final list =
                        ref.read(applicationControllerProvider).valueOrNull ?? [];
                    final updated = list.cast<VisaApplication?>().firstWhere(
                          (a) => a?.id == app.id,
                          orElse: () => app,
                        );
                    setState(() => _selected = updated ?? app.copyWith(status: s));
                  },
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Applications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(applicationControllerProvider.notifier).load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New draft'),
        onPressed: () async {
          await ref.read(applicationControllerProvider.notifier).createDraft(
                title: 'New Application Draft',
                programName: 'To be selected',
                country: '—',
              );
        },
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$e'),
              TextButton(
                onPressed: () =>
                    ref.read(applicationControllerProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (apps) {
          if (apps.isEmpty) {
            return const EmptyView(
              title: 'No applications yet',
              subtitle: 'Start a draft or explore Visa programs.',
              icon: Icons.assignment_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: apps.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final app = apps[index];
              return Card(
                child: ListTile(
                  title: Text(app.title),
                  subtitle: Text('${app.programName} · ${app.country}'),
                  trailing: Chip(
                    label: Text(
                      app.status.label,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    backgroundColor: _statusColor(app.status),
                    visualDensity: VisualDensity.compact,
                  ),
                  onTap: () => setState(() => _selected = app),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
