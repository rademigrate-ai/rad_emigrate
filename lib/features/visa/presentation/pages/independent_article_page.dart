import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../domain/entities/search_entities.dart';
import '../providers/canonical_pathway_controller.dart';

class IndependentArticlePage extends ConsumerWidget {
  final String countrySlug;
  final String articleSlug;

  const IndependentArticlePage({
    super.key,
    required this.countrySlug,
    required this.articleSlug,
  });

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            status.toDisplayPersian(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articleAsync = ref.watch(
      independentArticleProvider((
        countryCode: countrySlug,
        locale: Localizations.localeOf(context).languageCode,
        articleSlug: articleSlug,
      )),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: AppBackButton(fallback: '/visa/$countrySlug'),
        title: const Text('مقاله تخصصی'),
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
      body: articleAsync.when(
        loading: () => const Center(child: RadPending()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('خطا در دریافت مقاله: $err'),
          ),
        ),
        data: (article) {
          if (article == null) {
            return const Center(child: Text('مقاله مورد نظر یافت نشد.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
              Container(
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${article.countryName} • ${article.category}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navyMuted,
                            ),
                          ),
                        ),
                        _buildFactualBadge(article.factualStatus),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'زمان مطالعه: حدود ${article.readingTimeMinutes} دقیقه',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Canonical Pathway Link Banner (if associated)
              if (article.canonicalPathwaySlug != null)
                InkWell(
                  onTap: () => context.go(
                    '/visa/$countrySlug/${article.canonicalPathwaySlug}',
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(
                        color: AppColors.teal.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link, color: AppColors.teal, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'این مقاله بخشی از راهنمای جامع این کشور است. برای مشاهده کل شرایط ویزا اینجا را لمس کنید.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.teal,
                              height: 1.4,
                            ),
                          ),
                        ),
                        Icon(
                          directionalForward(context),
                          size: 14,
                          color: AppColors.teal,
                        ),
                      ],
                    ),
                  ),
                ),
              if (article.canonicalPathwaySlug != null)
                const SizedBox(height: 16),

              // Article Body
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  article.bodyMarkdown,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.8,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Official Sources Attribution Block
              if (article.officialSources.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
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
                            Icons.verified_user_outlined,
                            color: AppColors.success,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'منابع رسمی و مستندات دولتی',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...article.officialSources.map((src) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '• ',
                                style: TextStyle(color: AppColors.primaryRed),
                              ),
                              Expanded(
                                child: Text(
                                  '${src.authorityName} (${src.authorityDomain}) — پیوند مرجع: ${src.originalEvidenceUrl}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
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
            ],
          );
        },
      ),
    );
  }
}
