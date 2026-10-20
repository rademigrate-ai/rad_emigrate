import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/constrained_content.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/university_comparison.dart';
import '../providers/university_comparison_controller.dart';

class UniversityComparisonPage extends ConsumerStatefulWidget {
  const UniversityComparisonPage({super.key});

  @override
  ConsumerState<UniversityComparisonPage> createState() =>
      _UniversityComparisonPageState();
}

class _UniversityComparisonPageState
    extends ConsumerState<UniversityComparisonPage> {
  String? _countryFilter;

  @override
  Widget build(BuildContext context) {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final locale = isFa ? 'fa' : 'en';

    final query = UniversityQuery(
      countryFilter: _countryFilter,
      locale: locale,
    );

    final universitiesAsync = ref.watch(universityListProvider(query));

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/universities'),
        title: Text(
          isFa
              ? 'مقایسه دانشگاه‌ها و بورسیه‌ها'
              : 'Compare Universities & Scholarships',
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
                    ? 'مقایسه شهریه، رتبه جهانی QS، حداقل نمره زبان و وضعیت بورسیه‌های معتبر بین دانشگاه‌های برتر مهاجرت تحصیلی.'
                    : 'Compare tuition, QS rankings, language requirements, and verified scholarship options across top study destinations.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(isFa ? 'همه کشورها' : 'All countries'),
                      selected: _countryFilter == null,
                      onSelected: (selected) {
                        if (selected) setState(() => _countryFilter = null);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(isFa ? 'آلمان' : 'Germany'),
                      selected: _countryFilter == 'DE',
                      onSelected: (selected) {
                        if (selected) setState(() => _countryFilter = 'DE');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(isFa ? 'کانادا' : 'Canada'),
                      selected: _countryFilter == 'CA',
                      onSelected: (selected) {
                        if (selected) setState(() => _countryFilter = 'CA');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(isFa ? 'استرالیا' : 'Australia'),
                      selected: _countryFilter == 'AU',
                      onSelected: (selected) {
                        if (selected) setState(() => _countryFilter = 'AU');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              universitiesAsync.when(
                loading: () => const LoadingState.section(),
                error: (err, _) => Center(
                  child: Text(
                    isFa
                        ? 'خطا در دریافت فهرست دانشگاه‌ها'
                        : 'Error loading university data',
                  ),
                ),
                data: (universities) {
                  return Column(
                    children: universities.map((uni) {
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
                                        uni.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${uni.city}، ${uni.countryName}',
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
                                  label: uni.rankingRange,
                                  tone: StatusTone.info,
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            _UniRow(
                              icon: Icons.account_balance_wallet_outlined,
                              label: isFa ? 'شهریه سالانه:' : 'Annual Tuition:',
                              value: uni.annualTuition,
                            ),
                            _UniRow(
                              icon: Icons.language_outlined,
                              label: isFa
                                  ? 'شرط حداقل زبان:'
                                  : 'Language Requirement:',
                              value: uni.minLanguageRequirement,
                            ),
                            _UniRow(
                              icon: Icons.card_giftcard_outlined,
                              label: isFa
                                  ? 'وضعیت بورسیه:'
                                  : 'Scholarship Availability:',
                              value: uni.scholarshipLevel.label(isFa),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  uni.englishTaughtAvailable
                                      ? Icons.check_circle_outline
                                      : Icons.highlight_off,
                                  size: 16,
                                  color: uni.englishTaughtAvailable
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  uni.englishTaughtAvailable
                                      ? (isFa
                                            ? 'رشته‌های به زبان انگلیسی موجود است'
                                            : 'English-taught programs available')
                                      : (isFa
                                            ? 'فقط به زبان بومی کشور مقصد'
                                            : 'Native language only'),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
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

class _UniRow extends StatelessWidget {
  const _UniRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
