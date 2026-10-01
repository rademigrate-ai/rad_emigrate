import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/progress_steps.dart';
import '../../../../core/widgets/status_badge.dart';
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

  StatusTone _tone(ApplicationStatus s) {
    switch (s) {
      case ApplicationStatus.draft:
        return StatusTone.neutral;
      case ApplicationStatus.submitted:
        return StatusTone.info;
      case ApplicationStatus.reviewing:
      case ApplicationStatus.documentsRequired:
        return StatusTone.warning;
      case ApplicationStatus.approved:
      case ApplicationStatus.completed:
        return StatusTone.success;
      case ApplicationStatus.rejected:
        return StatusTone.danger;
    }
  }

  List<ProgressStep> _timeline(ApplicationStatus status) {
    final order = [
      ApplicationStatus.draft,
      ApplicationStatus.submitted,
      ApplicationStatus.reviewing,
      ApplicationStatus.approved,
      ApplicationStatus.completed,
    ];
    final labels = {
      ApplicationStatus.draft: 'Draft',
      ApplicationStatus.submitted: 'Submitted',
      ApplicationStatus.reviewing: 'Under review',
      ApplicationStatus.approved: 'Approved',
      ApplicationStatus.completed: 'Completed',
    };
    var currentIdx = order.indexOf(status);
    if (status == ApplicationStatus.documentsRequired) currentIdx = 2;
    if (status == ApplicationStatus.rejected) {
      return [
        const ProgressStep(label: 'Submitted', state: ProgressStepState.done),
        const ProgressStep(label: 'Under review', state: ProgressStepState.done),
        const ProgressStep(label: 'Rejected', state: ProgressStepState.current),
      ];
    }
    return [
      for (var i = 0; i < order.length; i++)
        ProgressStep(
          label: labels[order[i]]!,
          state: i < currentIdx
              ? ProgressStepState.done
              : i == currentIdx
                  ? ProgressStepState.current
                  : ProgressStepState.upcoming,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(applicationControllerProvider);

    if (_selected != null) {
      final app = _selected!;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(app.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _selected = null),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          app.programName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      StatusBadge(
                        label: app.status.label,
                        tone: _tone(app.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    app.country,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (app.notes != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      app.notes!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Progress', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            AppCard(child: ProgressSteps(steps: _timeline(app.status))),
            const SizedBox(height: 20),
            Text(
              'Update status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
                        ref.read(applicationControllerProvider).valueOrNull ??
                            [];
                    VisaApplication? updated;
                    for (final a in list) {
                      if (a.id == app.id) {
                        updated = a;
                        break;
                      }
                    }
                    setState(
                      () => _selected = updated ?? app.copyWith(status: s),
                    );
                  },
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Applications'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
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
                title: 'New application draft',
                programName: 'To be selected',
                country: '—',
              );
        },
      ),
      body: state.when(
        loading: () => const LoadingState(message: 'Loading applications…'),
        error: (e, _) => ErrorState(
          message: '$e',
          onRetry: () =>
              ref.read(applicationControllerProvider.notifier).load(),
        ),
        data: (apps) {
          if (apps.isEmpty) {
            return EmptyState(
              title: 'No applications yet',
              subtitle: 'Start a draft or explore visa programs.',
              icon: Icons.assignment_outlined,
              actionLabel: 'New draft',
              onAction: () {
                ref.read(applicationControllerProvider.notifier).createDraft(
                      title: 'New application draft',
                      programName: 'To be selected',
                      country: '—',
                    );
              },
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
            itemCount: apps.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final app = apps[index];
              return AppCard(
                onTap: () => setState(() => _selected = app),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${app.programName} · ${app.country}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      label: app.status.label,
                      tone: _tone(app.status),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
