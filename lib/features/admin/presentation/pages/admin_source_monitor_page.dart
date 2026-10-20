import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../data/admin_cms_repository.dart';
import '../../domain/entities/admin_cms_entities.dart';

final adminProposalsProvider =
    FutureProvider.autoDispose<List<AdminSourceChangeProposal>>((ref) async {
      final repo = ref.watch(adminCmsRepositoryProvider);
      return repo.listProposals();
    });

class AdminSourceMonitorPage extends ConsumerWidget {
  const AdminSourceMonitorPage({super.key});

  Widget _buildStatusBadge(SourceProposalReviewStatus status) {
    Color bg;
    Color fg;
    switch (status) {
      case SourceProposalReviewStatus.approved:
        bg = AppColors.success.withValues(alpha: 0.12);
        fg = AppColors.success;
        break;
      case SourceProposalReviewStatus.rejected:
        bg = AppColors.error.withValues(alpha: 0.12);
        fg = AppColors.error;
        break;
      case SourceProposalReviewStatus.pending:
        bg = AppColors.warning.withValues(alpha: 0.12);
        fg = AppColors.warning;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        status.toDisplayPersian(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposalsAsync = ref.watch(adminProposalsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/admin'),
        title: const Text('پایش منابع رسمی و مغایرت‌ها'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'فهرست مقالات CMS',
            icon: const Icon(Icons.article_outlined),
            onPressed: () => context.go('/admin/cms'),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: proposalsAsync.when(
        loading: () => const Center(child: RadPending()),
        error: (err, _) => Center(child: Text('خطا: $err')),
        data: (proposals) {
          if (proposals.isEmpty) {
            return const Center(child: Text('هیچ تغییر جدیدی یافت نشد.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: proposals.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final prop = proposals[index];

              return InkWell(
                onTap: () => context.go('/admin/sources/${prop.id}/review'),
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.account_balance,
                                size: 16,
                                color: AppColors.navy,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                prop.authorityName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                            ],
                          ),
                          _buildStatusBadge(prop.reviewStatus),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        prop.summaryOfChanges,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'دامنه مرجع: ${prop.authorityDomain}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'بررسی تغییرات خط‌به‌خط و تأیید انطباق',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryRed,
                            ),
                          ),
                          Icon(
                            directionalForward(context),
                            size: 13,
                            color: AppColors.primaryRed,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
