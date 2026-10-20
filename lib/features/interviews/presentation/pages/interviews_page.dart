// Interview scheduling: overview of the user's RAD session requests plus the
// appointment request form.
//
// External embassy/consulate appointments are never booked, confirmed, or
// shown with availability — selecting that kind is informational only and
// submission fails closed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/constrained_content.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/inline_alert.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../global_time/domain/city_catalog.dart';
import '../../../global_time/domain/timezone_engine.dart';
import '../../domain/appointment_time.dart';
import '../../domain/appointment_validation.dart';
import '../../domain/entities/interview_appointment.dart';
import '../interview_labels.dart';
import '../providers/appointment_controller.dart';

/// Interview scheduling page: overview + request form.
class InterviewsPage extends ConsumerStatefulWidget {
  const InterviewsPage({super.key});

  @override
  ConsumerState<InterviewsPage> createState() => _InterviewsPageState();
}

class _InterviewsPageState extends ConsumerState<InterviewsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  AppointmentKind _kind = AppointmentKind.radSession;
  String? _zoneId; // null = device zone
  DateTime? _startLocal;
  DateTime? _endLocal;
  String? _slotErrorKey;
  bool _slotTouched = false;
  bool _tzReady = TimezoneEngine.isReady;

  @override
  void initState() {
    super.initState();
    // Share the verified global_time timezone bootstrap; rebuild when ready.
    TimezoneEngine.ensureInitialized().then((_) {
      if (mounted && TimezoneEngine.isReady && !_tzReady) {
        setState(() => _tzReady = true);
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _errorText(String key, InterviewLabels labels) {
    switch (key) {
      case 'appointmentTitleRequired':
        return labels.titleRequired;
      case 'appointmentTitleTooShort':
        return labels.titleTooShort;
      case 'appointmentTitleTooLong':
        return labels.titleTooLong;
      case 'appointmentNotesTooLong':
        return labels.notesTooLong;
      case 'appointmentStartRequired':
        return labels.startRequired;
      case 'appointmentStartPast':
        return labels.startPast;
      case 'appointmentEndBeforeStart':
        return labels.endBeforeStart;
      case 'appointmentTooShort':
        return labels.tooShort;
      case 'appointmentTooLong':
        return labels.tooLong;
      case 'appointmentExternalNotBookable':
        return labels.kindExternalRefused;
      case 'appointmentBackendUnavailable':
        return labels.backendUnavailable;
      case 'appointmentRescheduleUnavailable':
        return labels.rescheduleUnavailable;
      case 'appointmentCancelUnavailable':
        return labels.cancelUnavailable;
      case 'appointmentDstGap':
        return labels.dstGap;
      case 'appointmentTzUnavailable':
        return labels.tzUnavailable;
      default:
        return labels.genericError;
    }
  }

  /// Civil start in the selected zone → UTC. Null = conversion impossible.
  DateTime? _startUtcOrNull() {
    if (_startLocal == null) return null;
    final zone = _zoneId;
    if (zone == null) return _startLocal!.toUtc();
    return CivilTimeInZone(
      year: _startLocal!.year,
      month: _startLocal!.month,
      day: _startLocal!.day,
      hour: _startLocal!.hour,
      minute: _startLocal!.minute,
      ianaZoneId: zone,
    ).toUtcOrNull();
  }

  DateTime? _endUtcOrNull() {
    if (_endLocal == null) return null;
    final zone = _zoneId;
    if (zone == null) return _endLocal!.toUtc();
    return CivilTimeInZone(
      year: _endLocal!.year,
      month: _endLocal!.month,
      day: _endLocal!.day,
      hour: _endLocal!.hour,
      minute: _endLocal!.minute,
      ianaZoneId: zone,
    ).toUtcOrNull();
  }

  bool get _isDstGap {
    final start = _startLocal;
    final zone = _zoneId;
    if (start == null || zone == null || !TimezoneEngine.isReady) return false;
    return CivilTimeInZone(
      year: start.year,
      month: start.month,
      day: start.day,
      hour: start.hour,
      minute: start.minute,
      ianaZoneId: zone,
    ).isDstGap;
  }

  bool get _isDstFold {
    final start = _startLocal;
    final zone = _zoneId;
    if (start == null || zone == null || !TimezoneEngine.isReady) return false;
    return CivilTimeInZone(
      year: start.year,
      month: start.month,
      day: start.day,
      hour: start.hour,
      minute: start.minute,
      ianaZoneId: zone,
    ).isDstFold;
  }

  /// Next quarter-hour at least [minAhead] minutes after [from].
  static DateTime _futureAlignedSeed(
    DateTime from, {
    int minAhead = 30,
    int stepMinutes = 15,
  }) {
    final earliest = from.add(Duration(minutes: minAhead));
    final totalMinutes = earliest.hour * 60 + earliest.minute;
    final remainder = totalMinutes % stepMinutes;
    final alignedMinutes = remainder == 0
        ? totalMinutes
        : totalMinutes + (stepMinutes - remainder);
    final dayCarry = alignedMinutes ~/ (24 * 60);
    final minutesInDay = alignedMinutes % (24 * 60);
    return DateTime(
      earliest.year,
      earliest.month,
      earliest.day,
      minutesInDay ~/ 60,
      minutesInDay % 60,
    ).add(Duration(days: dayCarry));
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    // Seed a future, quarter-hour-aligned default so accepting the picker
    // value is never "current minute" and always passes not-in-the-past.
    final seed = _startLocal ?? _futureAlignedSeed(now);
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 540)),
      initialDate: seed.isBefore(now) ? now : seed,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startLocal = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _slotTouched = true;
      _revalidateSlot();
    });
  }

  Future<void> _pickEnd() async {
    final base = _startLocal ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: base,
      lastDate: base.add(const Duration(days: 2)),
      initialDate: _endLocal ?? base,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endLocal ?? base),
    );
    if (time == null || !mounted) return;
    setState(() {
      _endLocal = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _slotTouched = true;
      _revalidateSlot();
    });
  }

  void _clearSlot() {
    setState(() {
      _startLocal = null;
      _endLocal = null;
      _slotTouched = false;
      _slotErrorKey = null;
    });
  }

  void _revalidateSlot() {
    if (!_slotTouched) {
      _slotErrorKey = null;
      return;
    }
    if (_isDstGap) {
      _slotErrorKey = 'appointmentDstGap';
      return;
    }
    final startUtc = _startUtcOrNull();
    if (startUtc == null && _startLocal != null && _zoneId != null) {
      _slotErrorKey = 'appointmentTzUnavailable';
      return;
    }
    final result = AppointmentValidation.validateStart(
      startUtc: startUtc,
      nowUtc: DateTime.now().toUtc(),
    );
    if (!result.isValid) {
      _slotErrorKey = result.errorKey;
      return;
    }
    final endResult = AppointmentValidation.validateEnd(
      endUtc: _endUtcOrNull(),
      startUtc: startUtc!,
    );
    _slotErrorKey = endResult.isValid ? null : endResult.errorKey;
  }

  Future<void> _submit(InterviewLabels labels) async {
    setState(() => _slotTouched = true);
    _revalidateSlot();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final startUtc = _startUtcOrNull();
    final validation = AppointmentValidation.validate(
      kind: _kind,
      title: _titleCtrl.text,
      notes: _notesCtrl.text,
      startUtc: startUtc,
      endUtc: _endUtcOrNull(),
      nowUtc: DateTime.now().toUtc(),
    );
    if (!validation.isValid) {
      setState(() {
        if (validation.field == 'start' ||
            validation.field == 'end' ||
            validation.field == 'kind') {
          _slotErrorKey = validation.errorKey;
        }
      });
      return;
    }

    final session = ref.read(authControllerProvider).valueOrNull;
    if (!(session?.isAuthenticated ?? false)) {
      GoRouter.maybeOf(context)?.go('/login?from=%2Finterviews');
      return;
    }

    final record = await ref
        .read(appointmentControllerProvider.notifier)
        .submit(
          title: _titleCtrl.text.trim(),
          startUtc: startUtc!,
          endUtc: _endUtcOrNull(),
          ianaZoneId: _zoneId,
          notes: _notesCtrl.text.trim(),
        );
    if (!mounted || record == null) return;
    setState(() {
      _titleCtrl.clear();
      _notesCtrl.clear();
      _startLocal = null;
      _endLocal = null;
      _slotTouched = false;
      _slotErrorKey = null;
    });
    ref.invalidate(appointmentListProvider);
  }

  StatusTone _tone(AppointmentStatus status) => switch (status) {
    AppointmentStatus.confirmed ||
    AppointmentStatus.completed => StatusTone.success,
    AppointmentStatus.cancelled => StatusTone.danger,
    AppointmentStatus.rescheduled => StatusTone.warning,
    AppointmentStatus.requested ||
    AppointmentStatus.inReview => StatusTone.info,
    AppointmentStatus.unknown => StatusTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final labels = InterviewLabels(locale);
    final theme = Theme.of(context);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final isAuthed = session?.isAuthenticated ?? false;
    final list = ref.watch(appointmentListProvider);
    final action = ref.watch(appointmentControllerProvider);
    final dateFormat = DateFormat.yMMMd(locale).add_Hm();

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/dashboard'),
        title: Text(labels.title),
      ),
      body: PremiumCanvas(
        accent: theme.colorScheme.secondary,
        child: ConstrainedContent(
          maxWidth: 860,
          alignment: Alignment.topCenter,
          child: MotionReveal(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    labels.intro,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    labels.overviewTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 10),
                ..._buildOverview(list, labels, dateFormat, locale),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(
                    labels.requestTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 10),
                AppCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          labels.kindLabel,
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            RadioListTile<AppointmentKind>(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                labels.kindRadSession,
                                softWrap: true,
                              ),
                              value: AppointmentKind.radSession,
                              groupValue: _kind,
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _kind = v;
                                  _slotErrorKey = null;
                                });
                              },
                            ),
                            RadioListTile<AppointmentKind>(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(labels.kindExternal, softWrap: true),
                              value: AppointmentKind.externalGovernment,
                              groupValue: _kind,
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _kind = v;
                                  _slotErrorKey = null;
                                });
                              },
                            ),
                          ],
                        ),
                        if (_kind == AppointmentKind.externalGovernment) ...[
                          const SizedBox(height: 8),
                          InlineAlert(
                            message: labels.kindExternalHelp,
                            error: false,
                          ),
                        ],
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _titleCtrl,
                          label: labels.titleLabel,
                          hint: labels.titleHint,
                          prefixIcon: Icons.event_note_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            final r = AppointmentValidation.validateTitle(
                              value,
                            );
                            return r.isValid
                                ? null
                                : _errorText(r.errorKey!, labels);
                          },
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppButton(
                              label: _startLocal == null
                                  ? '${labels.startLabel}: —'
                                  : '${labels.startLabel}: ${dateFormat.format(_startLocal!)}',
                              icon: Icons.schedule_outlined,
                              variant: AppButtonVariant.secondary,
                              expanded: true,
                              onPressed: _pickStart,
                            ),
                            AppButton(
                              label: _endLocal == null
                                  ? '${labels.endLabel}: —'
                                  : '${labels.endLabel}: ${dateFormat.format(_endLocal!)}',
                              icon: Icons.event_outlined,
                              variant: AppButtonVariant.secondary,
                              expanded: true,
                              onPressed: _pickEnd,
                            ),
                            if (_startLocal != null || _endLocal != null)
                              IconButton(
                                tooltip: labels.clearSlot,
                                icon: const Icon(Icons.clear_outlined),
                                onPressed: _clearSlot,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: _zoneId,
                          decoration: InputDecoration(
                            labelText: labels.zoneLabel,
                            prefixIcon: const Icon(Icons.public_outlined),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(labels.zoneDevice),
                            ),
                            for (final city in CityCatalog.all)
                              DropdownMenuItem<String?>(
                                value: city.timezone,
                                child: Text(
                                  '${city.nameEn} (${city.timezone})',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                          ],
                          onChanged: (value) => setState(() {
                            _zoneId = value;
                            _revalidateSlot();
                          }),
                        ),
                        if (_startLocal != null && _zoneId != null) ...[
                          const SizedBox(height: 10),
                          _ZonePreviews(
                            startLocal: _startLocal!,
                            endLocal: _endLocal,
                            zoneId: _zoneId!,
                            labels: labels,
                            dateFormat: dateFormat,
                            tzReady: _tzReady,
                          ),
                        ],
                        if (_slotErrorKey != null) ...[
                          const SizedBox(height: 10),
                          InlineAlert(
                            message: _errorText(_slotErrorKey!, labels),
                          ),
                        ] else if (_slotTouched && _isDstFold) ...[
                          const SizedBox(height: 10),
                          InlineAlert(
                            message: labels.ambiguousZone,
                            error: false,
                          ),
                        ],
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _notesCtrl,
                          label: labels.notesLabel,
                          prefixIcon: Icons.notes_outlined,
                          minLines: 2,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          validator: (value) {
                            final r = AppointmentValidation.validateNotes(
                              value,
                            );
                            return r.isValid
                                ? null
                                : _errorText(r.errorKey!, labels);
                          },
                        ),
                        const SizedBox(height: 14),
                        if (!isAuthed)
                          Text(
                            labels.signInRequired,
                            style: theme.textTheme.bodySmall,
                          ),
                        AppButton(
                          label: labels.submit,
                          icon: Icons.event_available_outlined,
                          loading: action.isRunning,
                          onPressed: action.isRunning
                              ? null
                              : () => _submit(labels),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          labels.notConfirmedNote,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (action.phase == AppointmentActionPhase.success) ...[
                  const SizedBox(height: 12),
                  InlineAlert(message: labels.success, error: false),
                ],
                if (action.phase == AppointmentActionPhase.failure) ...[
                  const SizedBox(height: 12),
                  InlineAlert(
                    message: _errorText(
                      action.errorKey ?? 'appointmentGenericError',
                      labels,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOverview(
    AsyncValue<AppointmentListResult> list,
    InterviewLabels labels,
    DateFormat dateFormat,
    String locale,
  ) {
    final action = ref.watch(appointmentControllerProvider);
    return list.when(
      loading: () => [const LoadingState.section()],
      error: (_, _) => [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                InlineAlert(message: labels.loadFailed),
                const SizedBox(height: 12),
                AppButton(
                  label: labels.retry,
                  icon: Icons.refresh,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => ref.invalidate(appointmentListProvider),
                ),
              ],
            ),
          ),
        ),
      ],
      data: (result) {
        if (result.capability == AppointmentCapability.backendUnavailable) {
          return [
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      labels.backendUnavailable,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ];
        }
        if (result.isEmpty) {
          return [
            EmptyState(
              title: labels.empty,
              icon: Icons.event_available_outlined,
            ),
          ];
        }
        return [
          for (final (index, appointment) in result.appointments.indexed)
            MotionStagger(
              index: index,
              child: AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          appointment.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        StatusBadge(
                          label: appointmentStatusLabel(
                            appointment.status.name,
                            labels,
                          ),
                          tone: _tone(appointment.status),
                        ),
                        StatusBadge(
                          label:
                              appointment.kind ==
                                  AppointmentKind.externalGovernment
                              ? labels.externalBadge
                              : labels.radBadge,
                          tone: StatusTone.neutral,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateFormat.format(appointment.startUtc.toLocal()),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (appointment.status.isOpen &&
                        appointment.kind == AppointmentKind.radSession) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.schedule_outlined, size: 16),
                            label: Text(labels.reschedule),
                            onPressed: action.isRunning
                                ? null
                                : () => _reschedule(appointment, labels),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.close_outlined, size: 16),
                            label: Text(labels.cancel),
                            onPressed: action.isRunning
                                ? null
                                : () => _confirmCancel(appointment, labels),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (action.phase == AppointmentActionPhase.failure &&
              action.backendUnavailable)
            InlineAlert(
              message: action.errorKey == 'appointmentCancelUnavailable'
                  ? labels.cancelUnavailable
                  : labels.rescheduleUnavailable,
            ),
        ];
      },
    );
  }

  Future<void> _reschedule(
    InterviewAppointment appointment,
    InterviewLabels labels,
  ) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 540)),
      initialDate: appointment.startUtc.toLocal(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(appointment.startUtc.toLocal()),
    );
    if (time == null || !mounted) return;
    final newStartLocal = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    await ref
        .read(appointmentControllerProvider.notifier)
        .reschedule(
          appointmentId: appointment.id,
          startUtc: newStartLocal.toUtc(),
          endUtc: appointment.endUtc,
          ianaZoneId: appointment.ianaZoneId,
          notes: appointment.notes,
        );
    if (mounted) ref.invalidate(appointmentListProvider);
  }

  Future<void> _confirmCancel(
    InterviewAppointment appointment,
    InterviewLabels labels,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(labels.cancel),
        content: Text(appointment.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(labels.retry),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(labels.cancel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(appointmentControllerProvider.notifier)
        .cancel(appointmentId: appointment.id, reason: 'user_request');
    if (mounted) ref.invalidate(appointmentListProvider);
  }
}

class _ZonePreviews extends StatelessWidget {
  const _ZonePreviews({
    required this.startLocal,
    required this.endLocal,
    required this.zoneId,
    required this.labels,
    required this.dateFormat,
    required this.tzReady,
  });

  final DateTime startLocal;
  final DateTime? endLocal;
  final String zoneId;
  final InterviewLabels labels;
  final DateFormat dateFormat;
  final bool tzReady;

  @override
  Widget build(BuildContext context) {
    if (!tzReady) {
      return Text(
        labels.tzUnavailable,
        style: Theme.of(context).textTheme.labelSmall,
      );
    }
    final startUtc = CivilTimeInZone(
      year: startLocal.year,
      month: startLocal.month,
      day: startLocal.day,
      hour: startLocal.hour,
      minute: startLocal.minute,
      ianaZoneId: zoneId,
    ).toUtcOrNull();
    final inZone = startUtc == null
        ? null
        : AppointmentTimeDisplay.inZone(startUtc, zoneId);
    final offset = AppointmentTimeDisplay.offsetLabel(zoneId, at: startUtc);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (startUtc != null)
          Text(
            '${labels.utcPreview}: ${DateFormat.yMMMd('en').add_Hm().format(startUtc)} UTC',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        if (inZone != null)
          Text(
            '${labels.zonePreview}: ${dateFormat.format(inZone)} ($offset)',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        if (startUtc == null)
          Text(
            labels.dstGap,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
