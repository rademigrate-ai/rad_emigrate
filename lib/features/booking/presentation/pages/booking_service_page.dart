// Service detail + booking request form.
//
// Submission states are explicit: idle, submitting, success, failure, and
// backend-unavailable. A successful submit only ever reflects a real Backend
// response — never an optimistic local confirmation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/constrained_content.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/inline_alert.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/entities/service_booking.dart';
import '../../domain/booking_validation.dart';
import '../booking_labels.dart';
import '../providers/booking_controller.dart';

/// Detail view for one service offering with its booking request form.
class BookingServicePage extends ConsumerStatefulWidget {
  const BookingServicePage({super.key, required this.serviceId});

  final String serviceId;

  @override
  ConsumerState<BookingServicePage> createState() => _BookingServicePageState();
}

class _BookingServicePageState extends ConsumerState<BookingServicePage> {
  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();

  DateTime? _startLocal;
  DateTime? _endLocal;
  String? _slotErrorKey;
  bool _slotTouched = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  String _errorText(String key, BookingLabels labels) {
    switch (key) {
      case 'bookingMessageRequired':
        return labels.messageRequired;
      case 'bookingMessageTooShort':
        return labels.messageTooShort;
      case 'bookingMessageTooLong':
        return labels.messageTooLong;
      case 'bookingSlotIncomplete':
        return labels.slotIncomplete;
      case 'bookingSlotOrder':
        return labels.slotOrder;
      case 'bookingSlotTooShort':
        return labels.slotTooShort;
      case 'bookingSlotTooLong':
        return labels.slotTooLong;
      case 'bookingSlotPast':
        return labels.slotPast;
      case 'bookingSlotRequired':
        return labels.preferredTimeRequired;
      default:
        return labels.genericError;
    }
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _startLocal ?? now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startLocal ?? now),
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
      _validateSlot();
    });
  }

  Future<void> _pickEnd() async {
    final base = _startLocal ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: base,
      lastDate: base.add(const Duration(days: 7)),
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
      _validateSlot();
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

  void _validateSlot() {
    final result = BookingValidation.validatePreferredSlot(
      startUtc: _startLocal?.toUtc(),
      endUtc: _endLocal?.toUtc(),
      nowUtc: DateTime.now().toUtc(),
    );
    _slotErrorKey = _slotTouched && !result.isValid ? result.errorKey : null;
  }

  Future<void> _submit(ServiceOffering service, BookingLabels labels) async {
    final validation = BookingValidation.validate(
      service: service,
      message: _messageCtrl.text,
      preferredStartUtc: _startLocal?.toUtc(),
      preferredEndUtc: _endLocal?.toUtc(),
      nowUtc: DateTime.now().toUtc(),
    );
    setState(() => _slotTouched = true);
    _validateSlot();
    if (!(_formKey.currentState?.validate() ?? false) || !validation.isValid) {
      if (validation.field == 'slot' && validation.errorKey != null) {
        setState(() => _slotErrorKey = validation.errorKey);
      }
      return;
    }

    final session = ref.read(verifiedUserSessionProvider);
    if (!(session?.isAuthenticated ?? false)) {
      final id = Uri.encodeComponent(service.id);
      // Graceful when no router is mounted (mirrors AppBackButton pattern).
      GoRouter.maybeOf(context)?.go('/login?from=%2Fbooking%2Fservice%2F$id');
      return;
    }

    final locale = Localizations.localeOf(context).languageCode;
    final record = await ref
        .read(bookingSubmitControllerProvider.notifier)
        .submit(
          service: service,
          request: BookingRequest(
            serviceId: service.id,
            message: _messageCtrl.text.trim(),
            preferredStartUtc: _startLocal?.toUtc(),
            preferredEndUtc: _endLocal?.toUtc(),
            timeZoneId: null,
          ),
          locale: locale,
        );
    if (!mounted) return;
    if (record != null) {
      setState(() {
        _messageCtrl.clear();
        _startLocal = null;
        _endLocal = null;
        _slotTouched = false;
        _slotErrorKey = null;
      });
      ref.invalidate(bookingHistoryProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final labels = BookingLabels(locale);
    final session = ref.watch(verifiedUserSessionProvider);
    final isAuthed = session?.isAuthenticated ?? false;
    final catalog = ref.watch(bookingCatalogProvider(locale));
    final submitState = ref.watch(bookingSubmitControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/booking'),
        title: Text(labels.serviceDetail),
      ),
      body: PremiumCanvas(
        accent: theme.colorScheme.secondary,
        child: catalog.when(
          loading: () => const LoadingState(),
          error: (_, _) => ErrorState(
            message: labels.genericError,
            onRetry: () => ref.invalidate(bookingCatalogProvider(locale)),
          ),
          data: (result) {
            ServiceOffering? service;
            for (final candidate in result.services) {
              if (candidate.id == widget.serviceId ||
                  candidate.slug == widget.serviceId) {
                service = candidate;
                break;
              }
            }
            if (service == null) {
              return ErrorState(
                message: labels.genericError,
                onRetry: () => context.go('/booking'),
              );
            }
            final effective = service;
            final requiresSlot =
                effective.fulfillment == BookingFulfillment.staffScheduled;
            final dateFormat = DateFormat.yMMMd(locale).add_Hm();

            return ConstrainedContent(
              maxWidth: 720,
              alignment: Alignment.topCenter,
              child: MotionReveal(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    effective.title,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                ),
                              ),
                              StatusBadge(
                                label:
                                    effective.fulfillment ==
                                        BookingFulfillment.humanConsultation
                                    ? labels.consultationBadge
                                    : labels.scheduledBadge,
                                tone: StatusTone.info,
                              ),
                            ],
                          ),
                          if (effective.description.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              effective.description,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            effective.durationMinutes == null
                                ? labels.durationUnavailable
                                : '${labels.durationLabel}: ${effective.durationMinutes} ${labels.minutesUnit}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            labels.noPriceNote,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              labels.requestDetails,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              controller: _messageCtrl,
                              label: labels.messageLabel,
                              hint: labels.messageHint,
                              prefixIcon: Icons.notes_outlined,
                              minLines: 3,
                              maxLines: 6,
                              textInputAction: TextInputAction.newline,
                              validator: (value) {
                                final result =
                                    BookingValidation.validateMessage(value);
                                return result.isValid
                                    ? null
                                    : _errorText(result.errorKey!, labels);
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              requiresSlot
                                  ? labels.preferredTimeRequired
                                  : labels.preferredTime,
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                AppButton(
                                  label: _startLocal == null
                                      ? labels.pickTime
                                      : dateFormat.format(_startLocal!),
                                  icon: Icons.schedule_outlined,
                                  variant: AppButtonVariant.secondary,
                                  expanded: false,
                                  onPressed: _pickStart,
                                ),
                                AppButton(
                                  label: _endLocal == null
                                      ? labels.pickTime
                                      : dateFormat.format(_endLocal!),
                                  icon: Icons.event_outlined,
                                  variant: AppButtonVariant.secondary,
                                  expanded: false,
                                  onPressed: _pickEnd,
                                ),
                                if (_startLocal != null || _endLocal != null)
                                  IconButton(
                                    tooltip: labels.clearSlotTooltip,
                                    icon: const Icon(Icons.clear_outlined),
                                    onPressed: _clearSlot,
                                  ),
                              ],
                            ),
                            if (_startLocal != null && _endLocal != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${labels.deviceTimeNote} (${dateFormat.format(_startLocal!)} — ${dateFormat.format(_endLocal!)})',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (_slotErrorKey != null) ...[
                              const SizedBox(height: 8),
                              InlineAlert(
                                message: _errorText(_slotErrorKey!, labels),
                              ),
                            ],
                            const SizedBox(height: 14),
                            if (!isAuthed)
                              Text(
                                labels.signInRequired,
                                style: theme.textTheme.bodySmall,
                              ),
                            AppButton(
                              label: labels.submit,
                              icon: Icons.send_outlined,
                              loading: submitState.isSubmitting,
                              onPressed: submitState.isSubmitting
                                  ? null
                                  : () => _submit(effective, labels),
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
                    if (submitState.phase == BookingSubmitPhase.success) ...[
                      const SizedBox(height: 12),
                      InlineAlert(message: labels.success, error: false),
                      const SizedBox(height: 8),
                      AppButton(
                        label: labels.myBookingsTitle,
                        variant: AppButtonVariant.secondary,
                        icon: Icons.event_note_outlined,
                        onPressed: () => context.go('/booking'),
                      ),
                    ],
                    if (submitState.phase == BookingSubmitPhase.failure) ...[
                      const SizedBox(height: 12),
                      InlineAlert(
                        message: submitState.backendUnavailable
                            ? labels.backendUnavailable
                            : _errorText(
                                submitState.errorKey ?? 'bookingGenericError',
                                labels,
                              ),
                      ),
                    ],
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
