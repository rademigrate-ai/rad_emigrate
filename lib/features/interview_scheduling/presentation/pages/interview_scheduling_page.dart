import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/constrained_content.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/interview_slot.dart';
import '../providers/interview_controller.dart';

class InterviewSchedulingPage extends ConsumerWidget {
  const InterviewSchedulingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final locale = isFa ? 'fa' : 'en';
    final slotsAsync = ref.watch(availableInterviewSlotsProvider(locale));

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/dashboard'),
        title: Text(
          isFa ? 'زمان‌بندی مصاحبه تخصصی' : 'Schedule Expert Interview',
        ),
      ),
      body: PremiumCanvas(
        child: ConstrainedContent(
          maxWidth: 860,
          alignment: Alignment.topCenter,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                isFa
                    ? 'جلسه مصاحبه تخصصی و شبیه‌سازی مصاحبه سفارت با کارشناسان رسمی RAD.'
                    : 'Professional interview preparation and embassy interview simulation with certified RAD advisors.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              slotsAsync.when(
                loading: () => const LoadingState.section(),
                error: (err, _) => AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isFa
                            ? 'سامانه زمان‌بندی خودکار در حال راه‌اندازی است'
                            : 'Automated scheduling backend is being prepared',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isFa
                            ? 'در حال حاضر رزرو مصاحبه از طریق فرم درخواست مشاوره تخصصی در دسترس است و هیچ زمان جعلی نمایش داده نمی‌شود.'
                            : 'Currently interview requests are scheduled via expert consultation requests; no synthetic slots are fabricated.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: isFa
                            ? 'درخواست مشاوره تخصصی'
                            : 'Request Consultation',
                        onPressed: () =>
                            context.push('/consultation'),
                      ),
                    ],
                  ),
                ),
                data: (slots) {
                  if (slots.isEmpty) {
                    return EmptyState(
                      title: isFa
                          ? 'در حال حاضر نوبت بازی موجود نیست'
                          : 'No available slots at this time',
                      icon: Icons.event_busy_outlined,
                    );
                  }
                  return Column(
                    children: slots.map((slot) {
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.video_call_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    slot.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat.yMMMd(locale)
                                        .add_jm()
                                        .format(slot.startUtc.toLocal()),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(
                              label: slot.mode.label(isFa),
                              tone: StatusTone.info,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
