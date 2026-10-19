import '../../../../core/widgets/rad_loading.dart';
import '../../../../core/errors/localized_error_message.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/reference_widgets.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../visa/presentation/widgets/country_photography.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/progress_steps.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/case_lifecycle.dart';
import '../../domain/entities/application_status.dart';
import '../../domain/entities/case_checklist.dart';
import '../../domain/entities/visa_application.dart';
import '../providers/application_controller.dart';
import '../providers/case_tracker_controller.dart';

class ApplicationsPage extends ConsumerStatefulWidget {
  final String? initialApplicationId;

  const ApplicationsPage({super.key, this.initialApplicationId});

  @override
  ConsumerState<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends ConsumerState<ApplicationsPage> {
  VisaApplication? _selected;
  int _filter = 0;
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

  String _checklistStatusLabel(ChecklistItemStatus s, bool isFa) {
    switch (s) {
      case ChecklistItemStatus.notStarted:
        return isFa ? 'شروع نشده' : 'Not Started';
      case ChecklistItemStatus.inProgress:
        return isFa ? 'در دست اقدام' : 'In Progress';
      case ChecklistItemStatus.completed:
        return isFa ? 'تکمیل شده' : 'Completed';
      case ChecklistItemStatus.blocked:
        return isFa ? 'مسدود / نیازمند اقدام' : 'Blocked';
      case ChecklistItemStatus.skipped:
        return isFa ? 'صرف‌نظر شده' : 'Skipped';
    }
  }

  Color _checklistStatusColor(ChecklistItemStatus s, BuildContext context) {
    switch (s) {
      case ChecklistItemStatus.notStarted:
        return context.premium.mutedText;
      case ChecklistItemStatus.inProgress:
        return context.premium.warning;
      case ChecklistItemStatus.completed:
        return context.premium.success;
      case ChecklistItemStatus.blocked:
        return context.premium.error;
      case ChecklistItemStatus.skipped:
        return Colors.blueGrey;
    }
  }

  IconData _checklistStatusIcon(ChecklistItemStatus s) {
    switch (s) {
      case ChecklistItemStatus.notStarted:
        return Icons.radio_button_unchecked;
      case ChecklistItemStatus.inProgress:
        return Icons.hourglass_top_outlined;
      case ChecklistItemStatus.completed:
        return Icons.check_circle_outlined;
      case ChecklistItemStatus.blocked:
        return Icons.block_outlined;
      case ChecklistItemStatus.skipped:
        return Icons.redo_outlined;
    }
  }

  String _transitionActionLabel(ChecklistItemStatus target, bool isFa) {
    switch (target) {
      case ChecklistItemStatus.notStarted:
        return isFa ? 'بازنشانی' : 'Reset';
      case ChecklistItemStatus.inProgress:
        return isFa ? 'شروع / ادامه' : 'Start / Resume';
      case ChecklistItemStatus.completed:
        return isFa ? 'تکمیل شد' : 'Complete';
      case ChecklistItemStatus.blocked:
        return isFa ? 'مسدود کردن' : 'Mark Blocked';
      case ChecklistItemStatus.skipped:
        return isFa ? 'صرف‌نظر' : 'Skip';
    }
  }

  Widget _metricChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Future<void> _showAddMilestoneDialog(
    BuildContext context,
    CaseTrackerController caseCtrl,
    bool isFa,
  ) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isFa ? 'افزودن مرحله جدید به چک‌لیست' : 'Add Case Milestone',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: isFa
                    ? 'عنوان مرحله / مدرک'
                    : 'Milestone Title / Document',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                labelText: isFa
                    ? 'توضیحات تکمیلی (اختیاری)'
                    : 'Description (Optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isFa ? 'انصراف' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final t = titleCtrl.text.trim();
              if (t.isNotEmpty) {
                caseCtrl.addChecklistItem(
                  title: t,
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  dueDate: DateTime.now().toUtc().add(const Duration(days: 14)),
                );
              }
              Navigator.pop(ctx);
            },
            child: Text(isFa ? 'افزودن' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNoteDialog(
    BuildContext context,
    CaseTrackerController caseCtrl,
    CaseChecklistItem item,
    bool isFa,
  ) async {
    final noteCtrl = TextEditingController(text: item.description ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFa ? 'یادداشت مرحله' : 'Milestone Notes'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: isFa ? 'متن یادداشت' : 'Note details',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isFa ? 'انصراف' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              caseCtrl.updateItemNote(item.id, noteCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: Text(isFa ? 'ذخیره' : 'Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItemWidget({
    required CaseChecklistItem item,
    required CaseTrackerController caseCtrl,
    required bool isFa,
    required BuildContext context,
    required DateTime now,
  }) {
    final statusColor = _checklistStatusColor(item.status, context);
    final isOverdue = item.isOverdue(now);
    final allowedTransitions = ChecklistItemStatus.values
        .where(
          (s) =>
              s != item.status &&
              ChecklistTransitionRules.canTransition(item.status, s),
        )
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.status == ChecklistItemStatus.blocked
              ? context.premium.error.withValues(alpha: 0.5)
              : (isOverdue
                    ? Colors.deepOrange.withValues(alpha: 0.4)
                    : context.premium.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _checklistStatusIcon(item.status),
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        decoration: item.status == ChecklistItemStatus.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _checklistStatusLabel(item.status, isFa),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (item.dueDate != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: context.premium.mutedText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isFa ? "سررسید:" : "Due:"} ${item.dueDate!.toIso8601String().split("T").first}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              if (isOverdue)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 12,
                        color: Colors.deepOrange,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isFa ? 'مهلت منقضی شده' : 'Overdue',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              InkWell(
                onTap: () => _showEditNoteDialog(context, caseCtrl, item, isFa),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_note,
                      size: 14,
                      color: context.premium.accent,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      isFa ? 'یادداشت' : 'Note',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.premium.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (allowedTransitions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              isFa ? 'تغییر وضعیت به:' : 'Transition to:',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final target in allowedTransitions)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      _transitionActionLabel(target, isFa),
                      style: TextStyle(
                        fontSize: 11,
                        color: _checklistStatusColor(target, context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    side: BorderSide(
                      color: _checklistStatusColor(
                        target,
                        context,
                      ).withValues(alpha: 0.3),
                    ),
                    backgroundColor: _checklistStatusColor(
                      target,
                      context,
                    ).withValues(alpha: 0.08),
                    onPressed: () =>
                        caseCtrl.transitionChecklistItem(item.id, target),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateStatus(
    VisaApplication app,
    ApplicationStatus status,
  ) async {
    if (_updatingStatus || app.status == status) return;
    final l10n = AppLocalizations.of(context);
    final isFa = Localizations.localeOf(context).languageCode == 'fa';

    if (!ApplicationStatusTransitions.canTransition(app.status, status)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFa
                  ? 'انتقال وضعیت از ${_statusLabel(app.status, l10n)} به ${_statusLabel(status, l10n)} مجاز نیست.'
                  : 'Cannot transition application from ${_statusLabel(app.status, l10n)} to ${_statusLabel(status, l10n)}.',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _updatingStatus = true);
    try {
      final caseCtrl = ref.read(caseTrackerControllerProvider(app).notifier);
      await caseCtrl.transitionApplicationStatus(status);
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
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final state = ref.watch(applicationControllerProvider);

    if (_selected == null && widget.initialApplicationId != null) {
      final list = state.valueOrNull ?? [];
      for (final a in list) {
        if (a.id == widget.initialApplicationId) {
          _selected = a;
          break;
        }
      }
    }

    if (_selected != null) {
      final app = _selected!;
      final caseState = ref.watch(caseTrackerControllerProvider(app));
      final caseCtrl = ref.read(caseTrackerControllerProvider(app).notifier);
      final checklist = caseState.checklist;
      final progress = caseState.progress;
      final reminders = caseState.reminders;

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
        body: PremiumCanvas(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                children: [
                  if (referenceCountryCode(app.country)
                      case final String code) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        height: 150,
                        width: double.infinity,
                        child: CountryPhotography.image(
                          code: code,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Application Profile Card
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
                  const SizedBox(height: 18),

                  // Progress Timeline
                  Text(
                    l10n.progress,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  AppCard(
                    child: ProgressSteps(steps: _timeline(app.status, l10n)),
                  ),
                  const SizedBox(height: 18),

                  // Allowed Application Status Transitions
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
                      final isCurrent = app.status == status;
                      final isAllowed =
                          ApplicationStatusTransitions.canTransition(
                            app.status,
                            status,
                          );
                      return FilterChip(
                        label: Text(_statusLabel(status, l10n)),
                        selected: isCurrent,
                        selectedColor: context.premium.accent,
                        avatar: isCurrent
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : (isAllowed
                                  ? null
                                  : const Icon(Icons.lock_outline, size: 14)),
                        labelStyle: TextStyle(
                          color: isCurrent
                              ? Colors.white
                              : (isAllowed
                                    ? context.premium.mutedText
                                    : context.premium.mutedText.withValues(
                                        alpha: 0.35,
                                      )),
                        ),
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

                  // ── Pending Reminders & Urgent Deadlines Card ──────
                  if (reminders.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    AppCard(
                      emphasized: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.alarm_on_rounded,
                                color: context.premium.warning,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isFa
                                      ? 'یادآورهای زمانی پرونده'
                                      : 'Pending Case Reminders',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: context.premium.warning,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isFa
                                ? 'مواعد اقدام به وقت ایران (UTC+03:30) و حوزه قضایی مقصد'
                                : 'Action deadlines in Iranian (UTC+03:30) and destination time context.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          for (final rem in reminders) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      rem.isPastDue(
                                        caseState.now ?? DateTime.now().toUtc(),
                                      )
                                      ? context.premium.error.withValues(
                                          alpha: 0.4,
                                        )
                                      : context.premium.warning.withValues(
                                          alpha: 0.3,
                                        ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    rem.isPastDue(
                                          caseState.now ??
                                              DateTime.now().toUtc(),
                                        )
                                        ? Icons.warning_rounded
                                        : Icons.schedule_rounded,
                                    size: 18,
                                    color:
                                        rem.isPastDue(
                                          caseState.now ??
                                              DateTime.now().toUtc(),
                                        )
                                        ? context.premium.error
                                        : context.premium.warning,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          rem.title ?? rem.itemId,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${isFa ? "سررسید:" : "Due:"} ${rem.dueDateUtc.toIso8601String().split("T").first} '
                                          '(${rem.dueDateUtc.add(const Duration(hours: 3, minutes: 30)).toIso8601String().split("T").last.substring(0, 5)} '
                                          '${isFa ? "به وقت ایران" : "Iran Time"})',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          rem.isPastDue(
                                            caseState.now ??
                                                DateTime.now().toUtc(),
                                          )
                                          ? context.premium.error.withValues(
                                              alpha: 0.15,
                                            )
                                          : context.premium.warning.withValues(
                                              alpha: 0.15,
                                            ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      rem.isPastDue(
                                            caseState.now ??
                                                DateTime.now().toUtc(),
                                          )
                                          ? (isFa ? 'سررسید گذشته' : 'Overdue')
                                          : (isFa ? 'موعد نزدیک' : 'Due Soon'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            rem.isPastDue(
                                              caseState.now ??
                                                  DateTime.now().toUtc(),
                                            )
                                            ? context.premium.error
                                            : context.premium.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // ── Case Milestones & Document Checklist Section ────
                  const SizedBox(height: 18),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                isFa
                                    ? 'چک‌لیست مراحل و مدارک پرونده'
                                    : 'Case Milestones & Document Checklist',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: progress.isComplete
                                    ? context.premium.success.withValues(
                                        alpha: 0.15,
                                      )
                                    : context.premium.accent.withValues(
                                        alpha: 0.15,
                                      ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${progress.percent}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: progress.isComplete
                                      ? context.premium.success
                                      : context.premium.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add_task),
                              tooltip: isFa
                                  ? 'افزودن مرحله جدید'
                                  : 'Add Milestone',
                              onPressed: () => _showAddMilestoneDialog(
                                context,
                                caseCtrl,
                                isFa,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress.ratio,
                            minHeight: 8,
                            backgroundColor: context.premium.border,
                            valueColor: AlwaysStoppedAnimation(
                              progress.isComplete
                                  ? context.premium.success
                                  : context.premium.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Summary status chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _metricChip(
                              label: isFa
                                  ? 'کل مراحل: ${progress.total}'
                                  : 'Total: ${progress.total}',
                              color: context.premium.mutedText,
                            ),
                            _metricChip(
                              label: isFa
                                  ? 'تکمیل شده: ${progress.completed}'
                                  : 'Done: ${progress.completed}',
                              color: context.premium.success,
                            ),
                            _metricChip(
                              label: isFa
                                  ? 'در دست اقدام: ${progress.inProgress}'
                                  : 'In Progress: ${progress.inProgress}',
                              color: context.premium.warning,
                            ),
                            if (progress.blocked > 0)
                              _metricChip(
                                label: isFa
                                    ? 'مسدود: ${progress.blocked}'
                                    : 'Blocked: ${progress.blocked}',
                                color: context.premium.error,
                              ),
                            if (progress.overdue > 0)
                              _metricChip(
                                label: isFa
                                    ? 'سررسید گذشته: ${progress.overdue}'
                                    : 'Overdue: ${progress.overdue}',
                                color: Colors.deepOrange,
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (checklist.items.isEmpty)
                          EmptyState(
                            title: isFa
                                ? 'چک‌لیستی برای این پرونده ثبت نشده است'
                                : 'No checklist items yet',
                            subtitle: isFa
                                ? 'می‌توانید مراحل پیش‌فرض را ایجاد کرده یا مرحله جدید اضافه نمایید.'
                                : 'You can create default milestones or add custom checklist items.',
                            icon: Icons.checklist_outlined,
                            actionLabel: isFa
                                ? 'ایجاد مراحل استاندارد'
                                : 'Create Default Milestones',
                            onAction: () => caseCtrl.setCustomChecklist(
                              defaultMilestoneItems(app),
                            ),
                          )
                        else ...[
                          for (final item in checklist.sortedByOrder()) ...[
                            _buildChecklistItemWidget(
                              item: item,
                              caseCtrl: caseCtrl,
                              isFa: isFa,
                              context: context,
                              now: caseState.now ?? DateTime.now().toUtc(),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
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
            tooltip: _creatingDraft ? l10n.creating : l10n.newDraft,
            onPressed: _creatingDraft ? null : _createDraft,
            icon: _creatingDraft
                ? const SizedBox(width: 20, height: 20, child: RadPending())
                : const Icon(Icons.add),
          ),
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
      body: PremiumCanvas(
        accent: AppColors.teal,
        child: state.when(
          loading: () =>
              LoadingState.section(message: l10n.loadingApplications),
          error: (e, _) => ErrorState(
            message: localizedDataError(e, l10n),
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
            final filtered = apps
                .where(
                  (app) =>
                      _filter == 0 ||
                      (_filter == 2
                          ? {
                              ApplicationStatus.completed,
                              ApplicationStatus.approved,
                            }.contains(app.status)
                          : !{
                              ApplicationStatus.completed,
                              ApplicationStatus.approved,
                              ApplicationStatus.rejected,
                            }.contains(app.status)),
                )
                .toList();
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final entry in [
                          l10n.allCases,
                          l10n.statusReviewing,
                          l10n.statusCompleted,
                        ].asMap().entries)
                          ChoiceChip(
                            label: Text(entry.value),
                            selected: _filter == entry.key,
                            selectedColor: context.premium.accent,
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              color: _filter == entry.key
                                  ? Colors.white
                                  : context.premium.mutedText,
                            ),
                            onSelected: (_) =>
                                setState(() => _filter = entry.key),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (filtered.isEmpty)
                      EmptyState(
                        title: l10n.noApplications,
                        subtitle: l10n.noApplicationsSubtitle,
                      ),
                    for (final app in filtered)
                      AppCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        onTap: () => setState(() => _selected = app),
                        child: Row(
                          children: [
                            ReferenceFlag(country: app.country, size: 44),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    app.programName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _statusLabel(app.status, l10n),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: _toneColor(
                                            _tone(app.status),
                                            context,
                                          ),
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Semantics(
                                    label:
                                        '${l10n.progress}: ${_statusLabel(app.status, l10n)}',
                                    child: Row(
                                      children: [
                                        for (final step in _timeline(
                                          app.status,
                                          l10n,
                                        ))
                                          Expanded(
                                            child: Container(
                                              height: 4,
                                              margin:
                                                  const EdgeInsetsDirectional.only(
                                                    end: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                color:
                                                    step.state ==
                                                        ProgressStepState
                                                            .upcoming
                                                    ? context.premium.border
                                                    : _toneColor(
                                                        _tone(app.status),
                                                        context,
                                                      ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              directionalChevron(context),
                              size: 18,
                              color: context.premium.mutedText,
                            ),
                          ],
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
  }
}

Color _toneColor(StatusTone tone, BuildContext context) => switch (tone) {
  StatusTone.success => context.premium.success,
  StatusTone.warning => context.premium.accentForeground,
  StatusTone.danger => context.premium.error,
  StatusTone.info => context.premium.information,
  StatusTone.neutral => context.premium.mutedText,
};
