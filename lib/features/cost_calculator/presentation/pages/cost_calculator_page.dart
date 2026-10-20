import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/constrained_content.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/cost_estimate.dart';
import '../providers/cost_calculator_controller.dart';

class CostCalculatorPage extends ConsumerStatefulWidget {
  const CostCalculatorPage({
    super.key,
    this.initialCountryCode = 'DE',
    this.initialPathwaySlug = 'chancenkarte',
  });

  final String initialCountryCode;
  final String initialPathwaySlug;

  @override
  ConsumerState<CostCalculatorPage> createState() => _CostCalculatorPageState();
}

class _CostCalculatorPageState extends ConsumerState<CostCalculatorPage> {
  late String _countryCode;
  late String _pathwaySlug;
  int _applicantsCount = 1;

  @override
  void initState() {
    super.initState();
    _countryCode = widget.initialCountryCode;
    _pathwaySlug = widget.initialPathwaySlug;
  }

  @override
  Widget build(BuildContext context) {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final locale = isFa ? 'fa' : 'en';

    final query = CostCalculatorQuery(
      countryCode: _countryCode,
      pathwaySlug: _pathwaySlug,
      applicantsCount: _applicantsCount,
      locale: locale,
    );

    final estimateAsync = ref.watch(costEstimateProvider(query));

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/visa'),
        title: Text(
          isFa ? 'محاسبه‌گر هزینه‌های مهاجرت' : 'Immigration Cost Calculator',
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
                    ? 'برآورد شفاف هزینه‌های دولتی، بیومتریک و حداقل تمکن مالی قانونی بر اساس آخرین تعرفه‌های رسمی.'
                    : 'Transparent estimate of official government fees, biometrics, and statutory proof of funds.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFa
                          ? 'انتخاب کشور و مسیر مهاجرتی'
                          : 'Select Country & Pathway',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(
                            isFa
                                ? 'آلمان — کارت شانس'
                                : 'Germany — Chancenkarte',
                          ),
                          selected: _countryCode == 'DE',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _countryCode = 'DE';
                                _pathwaySlug = 'chancenkarte';
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: Text(
                            isFa
                                ? 'کانادا — اکسپرس اینتری'
                                : 'Canada — Express Entry',
                          ),
                          selected: _countryCode == 'CA',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _countryCode = 'CA';
                                _pathwaySlug = 'express-entry';
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          isFa ? 'تعداد متقاضیان:' : 'Number of Applicants:',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _applicantsCount > 1
                              ? () => setState(() => _applicantsCount--)
                              : null,
                          tooltip: isFa ? 'کاهش' : 'Decrease',
                        ),
                        Text(
                          '$_applicantsCount',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _applicantsCount < 10
                              ? () => setState(() => _applicantsCount++)
                              : null,
                          tooltip: isFa ? 'افزایش' : 'Increase',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              estimateAsync.when(
                loading: () => const LoadingState.section(),
                error: (err, _) => Center(
                  child: Text(
                    isFa
                        ? 'خطا در بارگذاری برآورد هزینه‌ها'
                        : 'Error loading cost estimate',
                  ),
                ),
                data: (estimate) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  estimate.pathwayName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const Spacer(),
                                StatusBadge(
                                  label: estimate.baseCurrency,
                                  tone: StatusTone.info,
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            ...estimate.items.map((item) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                          Text(
                                            item.category.label(isFa),
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
                                    Text(
                                      '${item.amount.toStringAsFixed(0)} ${item.currency}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Text(
                                  isFa
                                      ? 'مجموع هزینه‌های پرداختی ویزا:'
                                      : 'Total Direct Fees:',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const Spacer(),
                                Text(
                                  '${estimate.totalMandatoryAmount.toStringAsFixed(0)} ${estimate.baseCurrency}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            if (estimate.settlementFundsAmount > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    isFa
                                        ? 'حداقل تمکن مالی قانونی (در حساب متقاضی):'
                                        : 'Proof of Funds Required:',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${estimate.settlementFundsAmount.toStringAsFixed(0)} ${estimate.baseCurrency}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          estimate.disclaimer,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
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
