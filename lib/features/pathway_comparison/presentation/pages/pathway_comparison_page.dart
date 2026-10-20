import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/constrained_content.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/pathway_comparison.dart';
import '../providers/pathway_comparison_controller.dart';

class PathwayComparisonPage extends ConsumerWidget {
  const PathwayComparisonPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final locale = isFa ? 'fa' : 'en';
    final itemsAsync = ref.watch(pathwayComparisonListProvider(locale));

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/visa'),
        title: Text(
          isFa ? 'مقایسه مسیرهای مهاجرتی' : 'Compare Immigration Pathways',
        ),
      ),
      body: PremiumCanvas(
        child: ConstrainedContent(
          maxWidth: 960,
          alignment: Alignment.topCenter,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                isFa
                    ? 'مقایسه تطبیقی شرایط، حداقل مدرک زبان، زمان بررسی و نوع اقامت در مقاصد اصلی مهاجرت کاری.'
                    : 'Side-by-side comparison of requirements, language levels, processing times, and residency status across major skilled pathways.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              itemsAsync.when(
                loading: () => const LoadingState.section(),
                error: (err, _) => Center(
                  child: Text(
                    isFa
                        ? 'خطا در بارگذاری اطلاعات مقایسه‌ای'
                        : 'Error loading comparison matrix',
                  ),
                ),
                data: (items) {
                  return Column(
                    children: items.map((item) {
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.countryName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.pathwayName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(
                                  label: item.directPermanentResidency
                                      ? (isFa
                                            ? 'اقامت دائم مستقیم'
                                            : 'Direct PR')
                                      : (isFa
                                            ? 'اقامت موقت به دائم'
                                            : 'Temporary to PR'),
                                  tone: item.directPermanentResidency
                                      ? StatusTone.success
                                      : StatusTone.info,
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            _ComparisonRow(
                              label: isFa
                                  ? 'مدرک زبان مورد نیاز:'
                                  : 'Language Requirement:',
                              value: item.minLanguageLevel,
                              icon: Icons.translate_outlined,
                            ),
                            _ComparisonRow(
                              label: isFa
                                  ? 'مدت زمان تقریبی بررسی:'
                                  : 'Estimated Processing Time:',
                              value: item.processingTimeRange,
                              icon: Icons.schedule_outlined,
                            ),
                            _ComparisonRow(
                              label: isFa
                                  ? 'نیاز به پیشنهاد کاری (Job Offer):'
                                  : 'Job Offer Required:',
                              value: item.jobOfferRequired
                                  ? (isFa
                                        ? 'بله، الزامی است'
                                        : 'Yes, mandatory')
                                  : (isFa
                                        ? 'خیر، بدون جاب‌آفر'
                                        : 'No, not required'),
                              icon: Icons.work_outline,
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant
                                    .withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.star_outline,
                                    size: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${isFa ? 'مزیت کلیدی:' : 'Key Advantage:'} ${item.keyAdvantage}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ),
                                ],
                              ),
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

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
