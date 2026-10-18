import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/inline_alert.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/reference_widgets.dart';
import '../../domain/entities/university_scholarship.dart';
import '../providers/university_scholarship_controller.dart';

class UniversityScholarshipPage extends ConsumerStatefulWidget {
  const UniversityScholarshipPage({super.key});

  @override
  ConsumerState<UniversityScholarshipPage> createState() =>
      _UniversityScholarshipPageState();
}

class _UniversityScholarshipPageState
    extends ConsumerState<UniversityScholarshipPage> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _degreeLabel(DegreeLevel level, bool isFa) {
    switch (level) {
      case DegreeLevel.bachelor:
        return isFa ? 'کارشناسی' : 'Bachelor';
      case DegreeLevel.master:
        return isFa ? 'کارشناسی ارشد' : 'Master';
      case DegreeLevel.doctorate:
        return isFa ? 'دکتری' : 'Doctorate';
      case DegreeLevel.diploma:
        return isFa ? 'دیپلم' : 'Diploma';
      case DegreeLevel.certificate:
        return isFa ? 'گواهینامه' : 'Certificate';
      case DegreeLevel.other:
      case DegreeLevel.unknown:
        return isFa ? 'سایر مقاطع' : 'Other Level';
    }
  }

  String _freshnessLabel(EvidenceFreshness f, bool isFa) {
    switch (f) {
      case EvidenceFreshness.fresh:
        return isFa ? 'منبع معتبر و به‌روز' : 'Verified & Fresh';
      case EvidenceFreshness.aging:
        return isFa ? 'منبع نیازمند بازبینی' : 'Aging Citation';
      case EvidenceFreshness.stale:
        return isFa ? 'منبع قدیمی / منقضی' : 'Stale Source';
      case EvidenceFreshness.unknown:
        return isFa ? 'منبع نامشخص' : 'Unknown Source';
      case EvidenceFreshness.conflicted:
        return isFa ? 'اختلاف در مراجع' : 'Conflicted Evidence';
    }
  }

  Color _freshnessColor(EvidenceFreshness f, BuildContext context) {
    switch (f) {
      case EvidenceFreshness.fresh:
        return context.premium.success;
      case EvidenceFreshness.aging:
        return context.premium.warning;
      case EvidenceFreshness.stale:
      case EvidenceFreshness.conflicted:
        return context.premium.error;
      case EvidenceFreshness.unknown:
        return context.premium.mutedText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(universityScholarshipControllerProvider);
    final controller = ref.read(
      universityScholarshipControllerProvider.notifier,
    );
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final now = state.clock ?? DateTime.now().toUtc();

    final isPrograms = state.activeTab == 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isFa
              ? 'دانشگاه‌ها و بورسیه‌های تحصیلی'
              : 'Universities & Scholarships',
        ),
        leading: const AppBackButton(fallback: '/visa'),
      ),
      body: PremiumCanvas(
        accent: AppColors.teal,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
              children: [
                // 1. Authoritative Evidence Disclaimer Banner
                InlineAlert(
                  error: false,
                  message: isFa
                      ? 'تمام داده‌ها مستقیماً از منابع رسمی آموزش عالی و نهادهای بورسیه‌دهنده دولتی استخراج شده‌اند. سیستم راد ای‌میگریت هیچ پیش‌بینی غیرمستند یا شانس قبولی ساختگی تولید نمی‌کند.'
                      : 'All records are curated directly from official university registries and government funding agencies. RAD Emigrate never produces speculative acceptance rates or visa promises.',
                ),
                const SizedBox(height: 14),

                // 2. Tab Selector
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<int>(
                        segments: [
                          ButtonSegment<int>(
                            value: 0,
                            icon: const Icon(Icons.school_outlined),
                            label: Text(
                              isFa ? 'برنامه‌های دانشگاهی' : 'Universities',
                            ),
                          ),
                          ButtonSegment<int>(
                            value: 1,
                            icon: const Icon(Icons.card_giftcard_outlined),
                            label: Text(
                              isFa ? 'بورسیه‌های تحصیلی' : 'Scholarships',
                            ),
                          ),
                        ],
                        selected: {state.activeTab},
                        onSelectionChanged: (set) {
                          controller.switchTab(set.first);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Search and Filters Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search input
                      AppTextField(
                        controller: _searchCtrl,
                        prefixIcon: Icons.search,
                        hint: isFa
                            ? 'جستجو بر اساس نام دانشگاه، رشته یا بورسیه...'
                            : 'Search by institution, field, or award...',
                        onChanged: (q) {
                          if (isPrograms) {
                            controller.updateUniversityFilter(query: q);
                          } else {
                            controller.updateScholarshipFilter(query: q);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Country Filters
                      Text(
                        isFa ? 'کشور مقصد:' : 'Country:',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(isFa ? 'همه کشورها' : 'All Countries'),
                            selected: isPrograms
                                ? state.universityFilter.countryCode == null
                                : state.scholarshipFilter.countryCode == null,
                            selectedColor: context.premium.accent,
                            labelStyle: TextStyle(
                              color:
                                  (isPrograms
                                          ? state.universityFilter.countryCode
                                          : state
                                                .scholarshipFilter
                                                .countryCode) ==
                                      null
                                  ? Colors.white
                                  : context.premium.mutedText,
                            ),
                            onSelected: (_) {
                              if (isPrograms) {
                                controller.updateUniversityFilter(
                                  clearCountry: true,
                                );
                              } else {
                                controller.updateScholarshipFilter(
                                  clearCountry: true,
                                );
                              }
                            },
                          ),
                          for (final country in ['CA', 'DE'])
                            ChoiceChip(
                              avatar: ReferenceFlag(
                                country: country == 'CA' ? 'Canada' : 'Germany',
                                size: 16,
                              ),
                              label: Text(
                                country == 'CA'
                                    ? (isFa ? 'کانادا' : 'Canada')
                                    : (isFa ? 'آلمان' : 'Germany'),
                              ),
                              selected: isPrograms
                                  ? state.universityFilter.countryCode ==
                                        country
                                  : state.scholarshipFilter.countryCode ==
                                        country,
                              selectedColor: context.premium.accent,
                              labelStyle: TextStyle(
                                color:
                                    (isPrograms
                                            ? state.universityFilter.countryCode
                                            : state
                                                  .scholarshipFilter
                                                  .countryCode) ==
                                        country
                                    ? Colors.white
                                    : context.premium.mutedText,
                              ),
                              onSelected: (_) {
                                if (isPrograms) {
                                  controller.updateUniversityFilter(
                                    countryCode: country,
                                  );
                                } else {
                                  controller.updateScholarshipFilter(
                                    countryCode: country,
                                  );
                                }
                              },
                            ),
                        ],
                      ),

                      if (isPrograms) ...[
                        const SizedBox(height: 12),
                        // Degree Level Filters
                        Text(
                          isFa ? 'مقطع تحصیلی:' : 'Degree Level:',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text(isFa ? 'همه مقاطع' : 'All Levels'),
                              selected:
                                  state.universityFilter.degreeLevel == null,
                              selectedColor: context.premium.accent,
                              labelStyle: TextStyle(
                                color:
                                    state.universityFilter.degreeLevel == null
                                    ? Colors.white
                                    : context.premium.mutedText,
                              ),
                              onSelected: (_) => controller
                                  .updateUniversityFilter(clearDegree: true),
                            ),
                            for (final level in [
                              DegreeLevel.bachelor,
                              DegreeLevel.master,
                              DegreeLevel.doctorate,
                            ])
                              ChoiceChip(
                                label: Text(_degreeLabel(level, isFa)),
                                selected:
                                    state.universityFilter.degreeLevel == level,
                                selectedColor: context.premium.accent,
                                labelStyle: TextStyle(
                                  color:
                                      state.universityFilter.degreeLevel ==
                                          level
                                      ? Colors.white
                                      : context.premium.mutedText,
                                ),
                                onSelected: (_) => controller
                                    .updateUniversityFilter(degreeLevel: level),
                              ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),
                      // Quality & Freshness Toggles
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: isPrograms
                                  ? state.universityFilter.requireFreshSource
                                  : state.scholarshipFilter.requireFreshSource,
                              onChanged: (val) {
                                if (isPrograms) {
                                  controller.updateUniversityFilter(
                                    requireFreshSource: val ?? false,
                                  );
                                } else {
                                  controller.updateScholarshipFilter(
                                    requireFreshSource: val ?? false,
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isFa
                                  ? 'فقط مراجع کاملاً به‌روز و فعال'
                                  : 'Require fresh verified sources only',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Content Area Based on Active Tab
                if (isPrograms)
                  _buildUniversityContent(
                    state.universityResult,
                    isFa,
                    context,
                    now,
                    controller,
                  )
                else
                  _buildScholarshipContent(
                    state.scholarshipResult,
                    isFa,
                    context,
                    now,
                    controller,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUniversityContent(
    UniversitySearchResult result,
    bool isFa,
    BuildContext context,
    DateTime now,
    UniversityScholarshipController controller,
  ) {
    if (result.state == CatalogResultState.empty || result.isEmpty) {
      return EmptyState(
        title: isFa
            ? 'هیچ برنامه دانشگاهی مطابق با جستجو یافت نشد'
            : 'No university programs found',
        subtitle: isFa
            ? 'می‌توانید فیلترهای جستجو را بازنشانی کرده یا عبارت دیگری جستجو کنید.'
            : 'Try resetting the filter criteria or searching for another term.',
        icon: Icons.school_outlined,
        actionLabel: isFa ? 'بازنشانی فیلترها' : 'Reset Filters',
        onAction: controller.resetFilters,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.state == CatalogResultState.unknownSource)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InlineAlert(
              error: true,
              message: isFa
                  ? 'توجه: برخی از نتایج فاقد استناد منبع رسمی هستند و باید با احتیاط ارزیابی شوند.'
                  : 'Notice: Some results lack verified primary source citations.',
            ),
          ),
        if (result.state == CatalogResultState.expiredSource)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InlineAlert(
              error: false,
              message: isFa
                  ? 'برخی از برنامه‌ها دارای استنادهای قدیمی هستند که نیازمند بازبینی دوره‌ای می‌باشند.'
                  : 'Some programs reference aging source citations subject to periodic review.',
            ),
          ),
        for (final prog in result.items) ...[
          _buildUniversityCard(prog, isFa, context, now),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildUniversityCard(
    UniversityProgram prog,
    bool isFa,
    BuildContext context,
    DateTime now,
  ) {
    final freshness = prog.source?.freshness(now) ?? EvidenceFreshness.unknown;
    final freshnessCol = _freshnessColor(freshness, context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReferenceFlag(
                country: prog.countryCode == 'CA' ? 'Canada' : 'Germany',
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prog.institutionName,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (prog.city != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        prog.city!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: context.premium.mutedText),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.premium.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _degreeLabel(prog.degreeLevel, isFa),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.premium.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            prog.programName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),

          // Tuition Row
          if (prog.tuition != null) ...[
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 16,
                  color: context.premium.mutedText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    prog.tuition!.amount == 0
                        ? (isFa
                              ? 'شهریه: رایگان / بدون شهریه دانشگاه دولتی'
                              : 'Tuition: Free / Tuition-free state institution')
                        : '${isFa ? "شهریه تقریبی:" : "Estimated Tuition:"} ${prog.tuition!.amount.toInt()} ${prog.tuition!.currencyCode}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: prog.tuition!.amount == 0
                          ? context.premium.success
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          if (prog.notes != null) ...[
            Text(
              prog.notes!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Authoritative Citation Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: freshnessCol.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: freshnessCol.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_outlined, size: 16, color: freshnessCol),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              prog.source?.publisher ?? 'Official Registry',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: freshnessCol,
                              ),
                            ),
                          ),
                          Text(
                            _freshnessLabel(freshness, isFa),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: freshnessCol,
                            ),
                          ),
                        ],
                      ),
                      if (prog.source != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${prog.source!.title}\n${prog.source!.url}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 10,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScholarshipContent(
    ScholarshipSearchResult result,
    bool isFa,
    BuildContext context,
    DateTime now,
    UniversityScholarshipController controller,
  ) {
    if (result.state == CatalogResultState.empty || result.isEmpty) {
      return EmptyState(
        title: isFa
            ? 'هیچ بورسیه‌ای مطابق با جستجو یافت نشد'
            : 'No scholarships found',
        subtitle: isFa
            ? 'می‌توانید فیلترهای جستجو را بازنشانی کرده یا عبارت دیگری جستجو کنید.'
            : 'Try resetting the filter criteria or searching for another term.',
        icon: Icons.card_giftcard_outlined,
        actionLabel: isFa ? 'بازنشانی فیلترها' : 'Reset Filters',
        onAction: controller.resetFilters,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final sch in result.items) ...[
          _buildScholarshipCard(sch, isFa, context, now),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildScholarshipCard(
    ScholarshipListing sch,
    bool isFa,
    BuildContext context,
    DateTime now,
  ) {
    final freshness = sch.source?.freshness(now) ?? EvidenceFreshness.unknown;
    final freshnessCol = _freshnessColor(freshness, context);
    final isExpired = sch.isDeadlinePassed(now);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReferenceFlag(
                country: sch.countryCode == 'CA' ? 'Canada' : 'Germany',
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sch.name,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (sch.institutionName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sch.institutionName!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: context.premium.mutedText),
                      ),
                    ],
                  ],
                ),
              ),
              if (sch.award != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.premium.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${sch.award!.amount.toInt()} ${sch.award!.currencyCode}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: context.premium.success,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (sch.eligibilitySummary != null) ...[
            Text(
              sch.eligibilitySummary!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
          ],

          // Deadline indicator
          if (sch.deadline != null) ...[
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 15,
                  color: isExpired
                      ? context.premium.error
                      : context.premium.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  '${isFa ? "مهلت اقدام:" : "Deadline:"} ${sch.deadline!.toIso8601String().split("T").first}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isExpired
                        ? context.premium.error
                        : context.premium.warning,
                  ),
                ),
                if (isExpired) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.premium.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isFa ? 'منقضی شده' : 'Expired',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.premium.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],

          if (sch.notes != null) ...[
            Text(
              sch.notes!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Official Citation Card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: freshnessCol.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: freshnessCol.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_outlined, size: 16, color: freshnessCol),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              sch.source?.publisher ?? 'Official Registry',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: freshnessCol,
                              ),
                            ),
                          ),
                          Text(
                            _freshnessLabel(freshness, isFa),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: freshnessCol,
                            ),
                          ),
                        ],
                      ),
                      if (sch.source != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${sch.source!.title}\n${sch.source!.url}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 10,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
