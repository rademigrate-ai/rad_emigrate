// Service catalog + booking history page.
//
// States handled explicitly: loading, empty, backend-unavailable, error,
// unauthenticated. No prices or durations are ever invented.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/constrained_content.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/entities/service_booking.dart';
import '../booking_labels.dart';
import '../providers/booking_controller.dart';

/// Booking entry page: catalog of services plus the user's booking history.
class BookingPage extends ConsumerWidget {
  const BookingPage({super.key});

  StatusTone _tone(BookingStatus status) => switch (status) {
    BookingStatus.confirmed => StatusTone.success,
    BookingStatus.completed => StatusTone.success,
    BookingStatus.cancelled => StatusTone.danger,
    BookingStatus.rescheduled => StatusTone.warning,
    BookingStatus.submitted || BookingStatus.inReview => StatusTone.info,
    BookingStatus.unknown => StatusTone.neutral,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = Localizations.localeOf(context).languageCode;
    final labels = BookingLabels(l10n);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final isAuthed = session?.isAuthenticated ?? false;
    final catalog = ref.watch(bookingCatalogProvider(l10n));
    final history = isAuthed
        ? ref.watch(currentBookingHistoryProvider)
        : const AsyncValue<List<BookingRecord>>.data([]);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/dashboard'),
        title: Text(labels.title),
      ),
      body: PremiumCanvas(
        accent: Theme.of(context).colorScheme.secondary,
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  labels.catalogTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                catalog.when(
                  loading: () => const LoadingState.section(),
                  error: (_, _) => ErrorState(
                    message: labels.genericError,
                    onRetry: () => ref.invalidate(bookingCatalogProvider(l10n)),
                  ),
                  data: (result) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (result.capability ==
                          BookingCapability.backendUnavailable)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CapabilityNote(
                            message: labels.backendUnavailable,
                          ),
                        ),
                      for (final (index, service) in result.services.indexed)
                        MotionStagger(
                          index: index,
                          child: AppCard(
                            margin: const EdgeInsets.only(bottom: 10),
                            onTap: () =>
                                context.push('/booking/service/${service.id}'),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  service.fulfillment ==
                                          BookingFulfillment.humanConsultation
                                      ? Icons.support_agent_outlined
                                      : Icons.event_available_outlined,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            service.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall,
                                          ),
                                          StatusBadge(
                                            label:
                                                service.fulfillment ==
                                                    BookingFulfillment
                                                        .humanConsultation
                                                ? labels.consultationBadge
                                                : labels.scheduledBadge,
                                            tone: StatusTone.info,
                                          ),
                                        ],
                                      ),
                                      if (service.description.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          service.description,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        service.durationMinutes == null
                                            ? labels.durationUnavailable
                                            : '${labels.durationLabel}: ${service.durationMinutes} ${labels.minutesUnit}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 18),
                        child: Text(
                          labels.noPriceNote,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAuthed) ...[
                  Text(
                    labels.myBookingsTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  history.when(
                    loading: () => const LoadingState.section(),
                    error: (_, _) => _CapabilityNote(
                      message: labels.historyFailed,
                      onRetry: () => ref.invalidate(bookingHistoryProvider),
                    ),
                    data: (records) {
                      if (records.isEmpty) {
                        return EmptyState(
                          title: labels.emptyHistory,
                          icon: Icons.event_note_outlined,
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (index, record) in records.indexed)
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
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          record.serviceTitle.isEmpty
                                              ? labels.title
                                              : record.serviceTitle,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        StatusBadge(
                                          label: bookingStatusLabel(
                                            record.status.name,
                                            labels,
                                          ),
                                          tone: _tone(record.status),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      DateFormat.yMMMd(l10n)
                                          .add_Hm()
                                          .format(record.createdAt.toLocal()),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ] else ...[
                  AppCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_outline),
                      title: Text(labels.signInRequired),
                      trailing: TextButton(
                        onPressed: () => context.go('/login?from=%2Fbooking'),
                        child: Text(labels.signIn),
                      ),
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
}

class _CapabilityNote extends StatelessWidget {
  const _CapabilityNote({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Icon(Icons.refresh)),
        ],
      ),
    );
  }
}
