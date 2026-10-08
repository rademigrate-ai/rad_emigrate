import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/progress_steps.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../l10n/app_localizations.dart';
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
  var _creatingDraft = false;
  var _updatingStatus = false;

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

  String _statusLabel(ApplicationStatus s, AppLocalizations l10n) {
    switch (s) {
      case ApplicationStatus.draft:
        return l10n.statusDraft;
      case ApplicationStatus.submitted:
        return l10n.statusSubmitted;
      case ApplicationStatus.reviewing:
        return l10n.statusReviewing;
      case ApplicationStatus.documentsRequired:
        return l10n.statusDocumentsRequired;
      case ApplicationStatus.approved:
        return l10n.statusApproved;
      case ApplicationStatus.rejected:
        return l10n.statusRejected;
      case ApplicationStatus.completed:
        return l10n.statusCompleted;
    }
  }

  List<ProgressStep> _timeline(
    ApplicationStatus status,
    AppLocalizations l10n,
  ) {
    const order = [
      ApplicationStatus.draft,
      ApplicationStatus.submitted,
      ApplicationStatus.reviewing,
      ApplicationStatus.approved,
      ApplicationStatus.completed,
    ];
    final labels = {
      ApplicationStatus.draft: l10n.statusDraft,
      ApplicationStatus.submitted: l10n.statusSubmitted,
      ApplicationStatus.reviewing: l10n.statusReviewing,
      ApplicationStatus.approved: l10n.statusApproved,
      ApplicationStatus.completed: l10n.statusCompleted,
    };
    var currentIdx = order.indexOf(status);
    if (status == ApplicationStatus.documentsRequired) currentIdx = 2;
    if (status == ApplicationStatus.rejected) {
      return [
        ProgressStep(
          label: l10n.statusSubmitted,
          state: ProgressStepState.done,
        ),
        ProgressStep(
          label: l10n.statusReviewing,
          state: ProgressStepState.done,
        ),
        ProgressStep(
          label: l10n.statusRejected,
          state: ProgressStepState.current,
        ),
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

  Future<void> _createDraft() async {
    if (_creatingDraft) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _creatingDraft = true);
    try {
      await ref
          .read(applicationControllerProvider.notifier)
          .createDraft(
            title: l10n.newApplicationDraft,
            programName: l10n.toBeSelected,
            country: '—',
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.couldNotCreateDraft)));
      }
    } finally {
      if (mounted) setState(() => _creatingDraft = false);
    }
  }

  Future<void> _updateStatus(
    VisaApplication app,
    ApplicationStatus status,
  ) async {
    if (_updatingStatus || app.status == status) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _updatingStatus = true);
    try {
      await ref
          .read(applicationControllerProvider.notifier)
          .updateStatus(app.id, status);
      final list = ref.read(applicationControllerProvider).valueOrNull ?? [];
      VisaApplication? updated;
      for (final item in list) {
        if (item.id == app.id) {
          updated = item;
          break;
        }
      }
      if (mounted) {
        setState(() => _selected = updated ?? app.copyWith(status: status));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.couldNotUpdateStatus)));
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(applicationControllerProvider);

    if (_selected != null) {
      final app = _selected!;
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(app.title),
          leading: IconButton(
            tooltip: l10n.backToApplications,
            icon: Icon(directionalBack(context)),
            onPressed: () => setState(() => _selected = null),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.programName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      StatusBadge(
                        label: _statusLabel(app.status, l10n),
                        tone: _tone(app.status),
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
                Text(
                  l10n.progress,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: ProgressSteps(steps: _timeline(app.status, l10n)),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.updateStatus,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.updateStatusHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ApplicationStatus.values.map((status) {
                    return FilterChip(
                      label: Text(_statusLabel(status, l10n)),
                      selected: app.status == status,
                      onSelected: _updatingStatus
                          ? null
                          : (_) => _updateStatus(app, status),
                    );
                  }).toList(),
                ),
                if (_updatingStatus) ...[
                  const SizedBox(height: 12),
                  RadInlineLoading(label: l10n.loading),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.applications),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: _creatingDraft
                ? null
                : () => ref.read(applicationControllerProvider.notifier).load(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        icon: _creatingDraft
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add),
        label: Text(_creatingDraft ? l10n.creating : l10n.newDraft),
        onPressed: _creatingDraft ? null : _createDraft,
      ),
      body: PremiumCanvas(
        accent: AppColors.teal,
        child: state.when(
          loading: () =>
              LoadingState.section(message: l10n.loadingApplications),
          error: (e, _) => ErrorState(
            message: l10n.errorGeneric,
            onRetry: () =>
                ref.read(applicationControllerProvider.notifier).load(),
          ),
          data: (apps) {
            if (apps.isEmpty) {
              return EmptyState(
                title: l10n.noApplications,
                subtitle: l10n.noApplicationsSubtitle,
                icon: Icons.assignment_outlined,
                actionLabel: l10n.newDraft,
                onAction: _createDraft,
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
                  itemCount: apps.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return PremiumHeroPanel(
                        kicker: const EditorialKicker(
                          index: '03',
                          label: 'CASE ROOM',
                          dark: true,
                        ),
                        title: l10n.applications,
                        body: l10n.caseOverviewSubtitle,
                        trailing: const RadOrbit(size: 180, showBrand: false),
                      );
                    }
                    final app = apps[index - 1];
                    return MotionStagger(
                      index: index - 1,
                      child: AppCard(
                        onTap: () => setState(() => _selected = app),
                        padding: EdgeInsets.zero,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 8,
                              color: _toneColor(_tone(app.status)),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CASE ${(index).toString().padLeft(2, '0')}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.teal,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1,
                                          ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      app.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${app.programName} · ${app.country}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 14),
                                    StatusBadge(
                                      label: _statusLabel(app.status, l10n),
                                      tone: _tone(app.status),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Color _toneColor(StatusTone tone) => switch (tone) {
  StatusTone.success => AppColors.success,
  StatusTone.warning => AppColors.warning,
  StatusTone.danger => AppColors.error,
  StatusTone.info => AppColors.teal,
  StatusTone.neutral => AppColors.navyMuted,
};
