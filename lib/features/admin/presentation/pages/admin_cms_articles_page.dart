import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../../visa/domain/entities/canonical_pathway_entities.dart';
import '../../../visa/domain/entities/search_entities.dart';
import '../../data/admin_cms_repository.dart';
import '../../domain/entities/admin_cms_entities.dart';

final adminCmsArticlesProvider =
    FutureProvider.autoDispose<List<AdminCmsArticleListItem>>((ref) async {
      final repo = ref.watch(adminCmsRepositoryProvider);
      return repo.listCmsArticles();
    });

class AdminCmsArticlesPage extends ConsumerStatefulWidget {
  const AdminCmsArticlesPage({super.key});

  @override
  ConsumerState<AdminCmsArticlesPage> createState() =>
      _AdminCmsArticlesPageState();
}

class _AdminCmsArticlesPageState extends ConsumerState<AdminCmsArticlesPage> {
  String _selectedFilter = 'all';

  Widget _buildFactualBadge(FactualStatus status) {
    Color bg;
    Color fg;
    switch (status) {
      case FactualStatus.verified:
        bg = AppColors.success.withValues(alpha: 0.12);
        fg = AppColors.success;
        break;
      case FactualStatus.incorrect:
        bg = AppColors.error.withValues(alpha: 0.12);
        fg = AppColors.error;
        break;
      case FactualStatus.incomplete:
      case FactualStatus.outdated:
      case FactualStatus.conflicting:
        bg = AppColors.warning.withValues(alpha: 0.12);
        fg = AppColors.warning;
        break;
      case FactualStatus.unverified:
        bg = AppColors.navyMuted.withValues(alpha: 0.10);
        fg = AppColors.navyMuted;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toDisplayPersian(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildEditorialBadge(ArticleEditorialStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toDisplayPersian(),
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final articlesAsync = ref.watch(adminCmsArticlesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/admin'),
        title: const Text('مدیریت مقالات و مسیرهای ویزا (CMS)'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'پایش منابع رسمی',
            icon: const Icon(Icons.source_outlined),
            onPressed: () => context.go('/admin/sources'),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top action banner for Source Monitor
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(
                  color: AppColors.teal.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_mode, color: AppColors.teal, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'پیشنهادهای پایش منابع را بررسی کنید؛ هیچ تغییری خودکار منتشر نمی‌شود.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => context.go('/admin/sources'),
                    child: const Text(
                      'بررسی تغییرات',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            // Filter row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('همه مقالات'),
                    selected: _selectedFilter == 'all',
                    onSelected: (_) => setState(() => _selectedFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('مسیرهای تجمیعی'),
                    selected: _selectedFilter == 'canonical',
                    onSelected: (_) =>
                        setState(() => _selectedFilter = 'canonical'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('عناوین مستقل'),
                    selected: _selectedFilter == 'independent',
                    onSelected: (_) =>
                        setState(() => _selectedFilter = 'independent'),
                  ),
                ],
              ),
            ),

            // List of articles
            Expanded(
              child: articlesAsync.when(
                loading: () => const Center(child: RadPending()),
                error: (err, _) => Center(child: Text('خطا: $err')),
                data: (articles) {
                  final filtered = articles.where((a) {
                    if (_selectedFilter == 'canonical') {
                      return a.articleType ==
                          SearchArticleType.canonicalPathway;
                    }
                    if (_selectedFilter == 'independent') {
                      return a.articleType ==
                          SearchArticleType.independentTopic;
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('مقاله‌ای برای نمایش وجود ندارد.'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isCanonical =
                          item.articleType ==
                          SearchArticleType.canonicalPathway;

                      return InkWell(
                        onTap: () {
                          context.go(
                            '/admin/cms/canonical/${item.id}?locale=${item.locale}',
                          );
                        },
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isCanonical
                                    ? AppColors.primaryRed.withValues(
                                        alpha: 0.1,
                                      )
                                    : AppColors.teal.withValues(alpha: 0.1),
                                child: Text(
                                  item.countryCode.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isCanonical
                                        ? AppColors.darkRed
                                        : AppColors.teal,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.title} (${item.locale})',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        _buildFactualBadge(item.factualStatus),
                                        const SizedBox(width: 6),
                                        _buildEditorialBadge(
                                          item.editorialStatus,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'منبع: ${item.authorityDomain}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      );
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
}
