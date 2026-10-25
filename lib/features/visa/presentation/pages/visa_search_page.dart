import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../domain/entities/search_entities.dart';
import '../providers/visa_search_controller.dart';
import '../widgets/safe_highlighted_text.dart';

class VisaSearchPage extends ConsumerStatefulWidget {
  final String? initialQuery;

  const VisaSearchPage({super.key, this.initialQuery});

  @override
  ConsumerState<VisaSearchPage> createState() => _VisaSearchPageState();
}

class _VisaSearchPageState extends ConsumerState<VisaSearchPage> {
  late final TextEditingController _textController;
  Timer? _debounceTimer;

  static const _popularQueries = [
    'حساب مسدود آلمان',
    'کارت فرصت Chancenkarte',
    'بلو کارت Blue Card',
    'اکسپرس اینتری کانادا',
    'بورسیه استانی DSU ایتالیا',
    'ویزای تمکن مالی پرتغال',
  ];

  static const _countries = [
    {'code': 'all', 'label': 'همه کشورها', 'flag': '🌍'},
    {'code': 'de', 'label': 'آلمان', 'flag': '🇩🇪'},
    {'code': 'ca', 'label': 'کانادا', 'flag': '🇨🇦'},
    {'code': 'it', 'label': 'ایتالیا', 'flag': '🇮🇹'},
    {'code': 'pt', 'label': 'پرتغال', 'flag': '🇵🇹'},
  ];

  static const _categories = ['همه', 'کاری', 'تحصیلی', 'مهاجرت دائم'];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(visaSearchControllerProvider.notifier)
            .search(
              widget.initialQuery!,
              locale: Localizations.localeOf(context).languageCode,
            );
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref
          .read(visaSearchControllerProvider.notifier)
          .search(query, locale: Localizations.localeOf(context).languageCode);
    });
  }

  void _onQuerySubmitted(String query) {
    _debounceTimer?.cancel();
    ref
        .read(visaSearchControllerProvider.notifier)
        .search(query, locale: Localizations.localeOf(context).languageCode);
  }

  void _onTagTapped(String tag) {
    _textController.text = tag;
    _onQuerySubmitted(tag);
  }

  Widget _buildFactualBadge(FactualStatus status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case FactualStatus.verified:
        bg = AppColors.success.withValues(alpha: 0.12);
        fg = AppColors.success;
        icon = Icons.verified_outlined;
        break;
      case FactualStatus.incorrect:
        bg = AppColors.error.withValues(alpha: 0.12);
        fg = AppColors.error;
        icon = Icons.cancel_outlined;
        break;
      case FactualStatus.incomplete:
      case FactualStatus.outdated:
      case FactualStatus.conflicting:
        bg = AppColors.warning.withValues(alpha: 0.12);
        fg = AppColors.warning;
        icon = Icons.warning_amber_rounded;
        break;
      case FactualStatus.unverified:
        bg = AppColors.navyMuted.withValues(alpha: 0.10);
        fg = AppColors.navyMuted;
        icon = Icons.help_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            status.toDisplayPersian(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(visaSearchControllerProvider);
    final notifier = ref.read(visaSearchControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/visa'),
        title: const Text('جستجوی هوشمند ویزا و مقالات'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Container
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _textController,
                    onChanged: _onQueryChanged,
                    onSubmitted: _onQuerySubmitted,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText:
                          'جستجو در کل متن مقالات، قوانین و عناوین مستقل...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.primaryRed,
                      ),
                      suffixIcon: _textController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              tooltip: 'پاک کردن',
                              onPressed: () {
                                _textController.clear();
                                notifier.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Country Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _countries.map((c) {
                        final isSelected =
                            (searchState.countryFilter == null &&
                                c['code'] == 'all') ||
                            (searchState.countryFilter == c['code']);
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: FilterChip(
                            selected: isSelected,
                            showCheckmark: false,
                            label: Text('${c['flag']} ${c['label']}'),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                            selectedColor: AppColors.navy,
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.navy
                                    : AppColors.border,
                              ),
                            ),
                            onSelected: (_) {
                              notifier.setCountryFilter(c['code']);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected =
                            (searchState.categoryFilter == null &&
                                cat == 'همه') ||
                            (searchState.categoryFilter == cat);
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            selected: isSelected,
                            label: Text(cat),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primaryRed
                                  : AppColors.textSecondary,
                            ),
                            selectedColor: AppColors.primaryRed.withValues(
                              alpha: 0.1,
                            ),
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primaryRed
                                    : AppColors.border.withValues(alpha: 0.6),
                              ),
                            ),
                            onSelected: (_) {
                              notifier.setCategoryFilter(cat);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.border),

            // Content Area
            Expanded(
              child: searchState.query.isEmpty
                  ? _buildEmptyInitialView()
                  : searchState.result.when(
                      loading: () => const Center(child: RadPending()),
                      error: (err, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'خطا در جستجو: $err',
                            style: const TextStyle(color: AppColors.error),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      data: (result) {
                        if (result.hits.isEmpty) {
                          return _buildNoResultsView(searchState.query);
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: result.hits.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final hit = result.hits[index];
                            return _buildHitCard(context, hit);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyInitialView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: const [
              Icon(Icons.auto_awesome, color: AppColors.teal, size: 20),
              SizedBox(width: 8),
              Text(
                'پرسش‌ها و کلمات پرجستجو',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _popularQueries.map((tag) {
              return ActionChip(
                label: Text(tag),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  color: AppColors.navyMuted,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  side: const BorderSide(color: AppColors.border),
                ),
                onPressed: () => _onTagTapped(tag),
              );
            }).toList(),
          ),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: AppColors.teal,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'موتور جستجوی تجمیعی و اعتبارسنجی شده',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'نتایج جستجو تمام متن مقالات جامع، شرایط امتیازدهی، مبالغ تمکن مالی و قوانین مصوب سفارتخانه‌ها را به صورت بی‌درنگ کاوش می‌کند.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
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

  Widget _buildNoResultsView(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_outlined,
              size: 56,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'موردی برای «$query» یافت نشد',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'کلمات کلیدی را تغییر دهید یا فیلتر کشور و دسته‌بندی را روی «همه» تنظیم کنید.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHitCard(BuildContext context, SearchHit hit) {
    final isCanonical = hit.articleType == SearchArticleType.canonicalPathway;

    return InkWell(
      onTap: () => context.go(hit.deepLinkRoute),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header metadata: Country + Category + Article Type Badge + Verification Status
            Row(
              children: [
                Text(
                  hit.countryName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    hit.category,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isCanonical
                        ? AppColors.primaryRed.withValues(alpha: 0.08)
                        : AppColors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isCanonical ? 'مسیر تجمیعی' : 'عنوان مستقل',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isCanonical ? AppColors.darkRed : AppColors.teal,
                    ),
                  ),
                ),
                const Spacer(),
                _buildFactualBadge(hit.factualStatus),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              hit.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),

            // Snippet with safe TextSpan highlighting
            SafeHighlightedText(
              text: hit.snippet,
              matchRanges: hit.matchRanges,
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            // Deep link action footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (hit.targetSectionAnchor != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bookmark_outline,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'بخش: ${hit.targetSectionAnchor}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'مشاهده متن کامل',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryRed,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      directionalForward(context),
                      size: 14,
                      color: AppColors.primaryRed,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
