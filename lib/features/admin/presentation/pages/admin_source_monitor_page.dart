import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/supabase/rad_contract.dart';
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

final adminAuthoritiesProvider =
    FutureProvider.autoDispose<List<Authority>>((ref) async {
      final repo = ref.watch(adminCmsRepositoryProvider);
      return repo.listOfficialAuthorities();
    });

class AdminSourceMonitorPage extends ConsumerStatefulWidget {
  const AdminSourceMonitorPage({super.key});

  @override
  ConsumerState<AdminSourceMonitorPage> createState() =>
      _AdminSourceMonitorPageState();
}

class _AdminSourceMonitorPageState
    extends ConsumerState<AdminSourceMonitorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Set<String> _refreshingAuthorities = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  Widget _buildAuthorityStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status.toLowerCase()) {
      case 'verified':
        bg = AppColors.success.withValues(alpha: 0.12);
        fg = AppColors.success;
        label = 'تأییدشده رسمی';
        break;
      case 'provisional':
        bg = AppColors.warning.withValues(alpha: 0.12);
        fg = AppColors.warning;
        label = 'موقت / در دست بررسی';
        break;
      case 'expired':
        bg = AppColors.error.withValues(alpha: 0.12);
        fg = AppColors.error;
        label = 'منقضی‌شده';
        break;
      case 'blacklisted':
        bg = Colors.black12;
        fg = Colors.black87;
        label = 'مسدود / نامعتبر';
        break;
      default:
        bg = AppColors.surfaceMuted;
        fg = AppColors.textSecondary;
        label = 'نامشخص';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Future<void> _refreshAuthority(String authorityId) async {
    setState(() => _refreshingAuthorities.add(authorityId));
    try {
      final repo = ref.read(adminCmsRepositoryProvider);
      final res = await repo.enqueueResearchRefresh(
        authorityIds: [authorityId],
        requestKey: newRadRequestKey(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['deduplicated'] == true
              ? 'درخواست واکشی قبلاً در صف قرار گرفته است.'
              : 'فرمان واکشی منبع رسمی با موفقیت در صف قرار گرفت.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در واکشی: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _refreshingAuthorities.remove(authorityId));
      }
    }
  }

  void _showDiscoverDialog() {
    final countryController = TextEditingController(text: 'CA');
    final topicController = TextEditingController(text: 'immigration');
    final professionController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        var loading = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('شناسایی و کشف مراجع رسمی جدید'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: countryController,
                    decoration: const InputDecoration(
                      labelText: 'کد کشور (مانند CA, DE, AU)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: topicController,
                    decoration: const InputDecoration(
                      labelText: 'موضوع تخصصی (مانند immigration)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: professionController,
                    decoration: const InputDecoration(
                      labelText: 'حرفه یا تخصص (اختیاری)',
                    ),
                  ),
                  if (loading) ...[
                    const SizedBox(height: 16),
                    const RadPending(),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('انصراف'),
                ),
                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(dialogCtx);
                          setDialogState(() => loading = true);
                          try {
                            final repo = ref.read(adminCmsRepositoryProvider);
                            await repo.discoverOfficialAuthorities(
                              countryCode: countryController.text.trim(),
                              topic: topicController.text.trim(),
                              profession: professionController.text.trim().isEmpty
                                  ? null
                                  : professionController.text.trim(),
                              requestKey: newRadRequestKey(),
                            );
                            if (!mounted) return;
                            nav.pop();
                            ref.invalidate(adminAuthoritiesProvider);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('درخواست شناسایی مراجع رسمی ثبت شد.'),
                              ),
                            );
                          } catch (e) {
                            if (mounted) {
                              setDialogState(() => loading = false);
                              messenger.showSnackBar(
                                SnackBar(content: Text('خطا: $e')),
                              );
                            }
                          }
                        },
                  child: const Text('آغاز کاوش'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final proposalsAsync = ref.watch(adminProposalsProvider);
    final authoritiesAsync = ref.watch(adminAuthoritiesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/admin'),
        title: const Text('پایش منابع رسمی و مغایرت‌ها'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'شناسایی مرجع جدید',
            icon: const Icon(Icons.explore_outlined),
            onPressed: _showDiscoverDialog,
          ),
          IconButton(
            tooltip: 'فهرست مقالات CMS',
            icon: const Icon(Icons.article_outlined),
            onPressed: () => context.go('/admin/cms'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryRed,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryRed,
          tabs: const [
            Tab(text: 'پیشنهادهای مغایرت'),
            Tab(text: 'مراجع رسمی و معتبر'),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: Proposals list
          proposalsAsync.when(
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

          // Tab 1: Official Authorities list
          authoritiesAsync.when(
            loading: () => const Center(child: RadPending()),
            error: (err, _) => Center(child: Text('خطا: $err')),
            data: (authorities) {
              if (authorities.isEmpty) {
                return const Center(
                  child: Text('مرجع رسمی فعالی ثبت نشده است.'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: authorities.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final auth = authorities[index];
                  final isRefreshing = _refreshingAuthorities.contains(auth.id);

                  return Container(
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
                            Expanded(
                              child: Text(
                                auth.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            _buildAuthorityStatusBadge(auth.verificationState),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'حوزه قضایی: ${auth.jurisdiction}${auth.countryCode != null ? ' (${auth.countryCode})' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (auth.officialDomains.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'دامنه‌های مجاز: ${auth.officialDomains.join(', ')}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: isRefreshing
                                  ? null
                                  : () => _refreshAuthority(auth.id),
                              icon: isRefreshing
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: RadPending(),
                                    )
                                  : const Icon(Icons.refresh, size: 16),
                              label: Text(
                                isRefreshing ? 'در حال ارسال…' : 'واکشی تغییرات منبع',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
