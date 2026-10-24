import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../domain/entities/canonical_pathway_entities.dart';
import '../../domain/entities/search_entities.dart';
import '../../data/canonical_pathway_repository.dart';
import '../providers/canonical_pathway_controller.dart';
import '../widgets/article_change_highlights_banner.dart';
import '../widgets/currency_converter_modal.dart';

class CanonicalPathwayPage extends ConsumerStatefulWidget {
  final String countrySlug;
  final String pathwaySlug;
  final String? initialSectionAnchor;
  final String? articleId;
  final String? resolvedLocale;
  final String? requestedLocale;

  const CanonicalPathwayPage({
    super.key,
    required this.countrySlug,
    required this.pathwaySlug,
    this.initialSectionAnchor,
    this.articleId,
    this.resolvedLocale,
    this.requestedLocale,
  });

  @override
  ConsumerState<CanonicalPathwayPage> createState() =>
      _CanonicalPathwayPageState();
}

class _CanonicalPathwayPageState extends ConsumerState<CanonicalPathwayPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  String? _activeAnchor;
  bool _initialScrollScheduled = false;

  @override
  void initState() {
    super.initState();
    _activeAnchor = widget.initialSectionAnchor;
    if (_activeAnchor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSection(_activeAnchor!);
      });
    }
  }

  @override
  void didUpdateWidget(covariant CanonicalPathwayPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articleId != widget.articleId ||
        oldWidget.pathwaySlug != widget.pathwaySlug ||
        oldWidget.initialSectionAnchor != widget.initialSectionAnchor) {
      _activeAnchor = widget.initialSectionAnchor;
      _initialScrollScheduled = false;
      _sectionKeys.clear();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(String anchor) {
    if (!mounted) return;
    setState(() => _activeAnchor = anchor);
    final key = _sectionKeys[anchor];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        alignment: 0.08,
      );
    }
  }

  GlobalKey _getOrCreateKey(String anchor) {
    return _sectionKeys.putIfAbsent(anchor, () => GlobalKey());
  }

  void _openCurrencyModal(BuildContext context, double defaultEurAmount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CurrencyConverterModal(
        initialCurrency: 'EUR',
        initialAmount: defaultEurAmount > 0 ? defaultEurAmount : 1027.0,
      ),
    );
  }

  Widget _buildFactualBadge(
    FactualStatus status,
    List<OfficialSourceAttribution> sources,
  ) {
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

    final primarySource = sources.isNotEmpty ? sources.first : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'وضعیت انطباق با منبع رسمی: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    Text(
                      status.toDisplayPersian(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                  ],
                ),
                if (primarySource != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'مرجع دولتی: ${primarySource.authorityName} (${primarySource.authorityDomain})',
                    style: TextStyle(
                      fontSize: 11,
                      color: fg.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pathwayAsync = ref.watch(
      widget.articleId != null
          ? publishedVisaArticleProvider((
              articleId: widget.articleId!,
              requestedLocale:
                  widget.requestedLocale ??
                  Localizations.localeOf(context).languageCode,
              resolvedLocale:
                  widget.resolvedLocale ??
                  Localizations.localeOf(context).languageCode,
            ))
          : canonicalPathwayProvider((
              countryCode: widget.countrySlug,
              locale:
                  widget.resolvedLocale ??
                  Localizations.localeOf(context).languageCode,
              pathwaySlug: widget.pathwaySlug,
            )),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/visa'),
        title: const Text('راهنمای جامع ویزا'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/visa/search'),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: pathwayAsync.when(
        loading: () => const Center(child: RadPending()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('خطا در دریافت اطلاعات: $err'),
          ),
        ),
        data: (article) {
          if (article == null) {
            return const Center(child: Text('مقاله مورد نظر یافت نشد.'));
          }

          final tocAnchors = [
            {'anchor': 'article-overview', 'label': 'معرفی کلی'},
            for (final section in article.sections)
              {'anchor': section.anchor, 'label': section.title},
            if (article.eligibility != null)
              {'anchor': 'eligibility', 'label': 'شرایط و امتیازات'},
            if (article.costs.isNotEmpty)
              {'anchor': 'financial-costs', 'label': 'هزینه‌ها و تمکن'},
            if (article.steps.isNotEmpty)
              {'anchor': 'steps', 'label': 'مراحل اقدام'},
            if (article.requiredDocuments.isNotEmpty)
              {'anchor': 'documents', 'label': 'مدارک'},
            if (article.faqItems.isNotEmpty)
              {'anchor': 'faq', 'label': 'پرسش‌های متداول'},
            if (article.relatedArticles.isNotEmpty)
              {'anchor': 'related', 'label': 'عناوین دیگر'},
          ];

          if (!_initialScrollScheduled && _activeAnchor != null) {
            _initialScrollScheduled = true;
            final requested = _activeAnchor!;
            final sections = article.sections.where(
              (s) => s.id == requested || s.anchor == requested,
            );
            final anchor = sections.isEmpty ? requested : sections.first.anchor;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollToSection(anchor),
            );
          }
          return Column(
            children: [
              // Sticky TOC Bar
              Container(
                height: 46,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tocAnchors.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = tocAnchors[index];
                    final isCurrent = _activeAnchor == item['anchor'];
                    return Center(
                      child: ActionChip(
                        label: Text(item['label']!),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isCurrent
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                        backgroundColor: isCurrent
                            ? AppColors.navy
                            : AppColors.surfaceMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          side: BorderSide.none,
                        ),
                        onPressed: () => _scrollToSection(item['anchor']!),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.border),

              // Scrollable Article Body
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header Card
                    Container(
                      key: _getOrCreateKey('article-overview'),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                article.countryFlag,
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    article.countryName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    article.category,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primaryRed,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            article.pathwayTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            article.summary,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFactualBadge(
                            article.factualStatus,
                            article.officialSources,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    ArticleChangeHighlightsBanner(
                      lastFactCheckedAt: article.lastFactCheckedAt,
                      officialSources: article.officialSources,
                      sections: article.sections,
                    ),

                    // Custom Sections from Pathway
                    for (final sec in article.sections) ...[
                      Container(
                        key: _getOrCreateKey(sec.anchor),
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sec.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              sec.bodyMarkdown,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                height: 1.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Financial Costs Card with Currency Converter Shortcut
                    if (article.costs.isNotEmpty)
                      Container(
                        key: _getOrCreateKey('financial-costs'),
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: AppColors.teal,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'هزینه‌های رسمی و تمکن مالی',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    backgroundColor: AppColors.teal.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.currency_exchange,
                                    size: 14,
                                    color: AppColors.teal,
                                  ),
                                  label: const Text(
                                    'تبدیل به تومان/ریال',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.teal,
                                    ),
                                  ),
                                  onPressed: () {
                                    final totalEur = article.costs
                                        .where((c) => c.currency == 'EUR')
                                        .fold(0.0, (sum, c) => sum + c.amount);
                                    _openCurrencyModal(context, totalEur);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ...article.costs.map((cost) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cost.label,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (cost.description != null)
                                            Text(
                                              cost.description!,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textTertiary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${cost.amount.toStringAsFixed(0)} ${cost.currency}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                    // Process Steps Timeline
                    if (article.steps.isNotEmpty)
                      Container(
                        key: _getOrCreateKey('steps'),
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'مراحل قانونی و فرآیند درخواست',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ...article.steps.map((st) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: AppColors.navy,
                                      child: Text(
                                        '${st.stepNumber}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            st.title,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            st.description,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              height: 1.5,
                                            ),
                                          ),
                                          if (st.estimatedWeeks != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'مدت تخمینی: حدود ${st.estimatedWeeks} هفته',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.teal,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                    // Required Documents
                    if (article.requiredDocuments.isNotEmpty)
                      Container(
                        key: _getOrCreateKey('documents'),
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'چک‌لیست مدارک مورد نیاز سفارت',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...article.requiredDocuments.map((doc) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline,
                                      size: 16,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        doc,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                    // Related Independent Articles («عناوین دیگر»)
                    if (article.relatedArticles.isNotEmpty)
                      Container(
                        key: _getOrCreateKey('related'),
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.library_books_outlined,
                                  color: AppColors.primaryRed,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'عناوین دیگر و مقالات تخصصی مرتبط',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ...article.relatedArticles.map((rel) {
                              return InkWell(
                                onTap: () =>
                                    context.go('/visa/articles/${rel.id}'),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.md,
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.md,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              rel.title,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              rel.summary,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        directionalForward(context),
                                        size: 14,
                                        color: AppColors.textTertiary,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
