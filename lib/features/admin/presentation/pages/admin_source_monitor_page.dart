import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/supabase/rad_contract.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../data/admin_cms_repository.dart';
import '../../domain/entities/admin_cms_entities.dart';
import '../widgets/source_provenance_badge.dart';
import 'admin_source_dialog.dart';

final adminProposalsProvider =
    FutureProvider.autoDispose<List<AdminSourceChangeProposal>>((ref) async {
      final repo = ref.watch(adminCmsRepositoryProvider);
      return repo.listProposals();
    });

final adminAuthoritiesProvider = FutureProvider.autoDispose<List<Authority>>((
  ref,
) async {
  final repo = ref.watch(adminCmsRepositoryProvider);
  return repo.listOfficialAuthorities();
});

class AdminSourceMonitorPage extends ConsumerStatefulWidget {
  const AdminSourceMonitorPage({super.key});

  @override
  ConsumerState<AdminSourceMonitorPage> createState() =>
      _AdminSourceMonitorPageState();
}

class _AdminSourceMonitorPageState extends ConsumerState<AdminSourceMonitorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Set<String> _refreshingAuthorities = {};

  // Findings Filters
  String _findingsCountryFilter = 'all';
  String _findingsStatusFilter = 'all';
  String _findingsSearchQuery = '';

  // Sources Filters
  String _sourcesTypeFilter = 'all';
  String _sourcesCountryFilter = 'all';
  String _sourcesSearchQuery = '';

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
        bg = AppColors.teal.withValues(alpha: 0.12);
        fg = AppColors.teal;
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
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toDisplayPersian(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildChangeTypeBadge(String type) {
    String label;
    IconData icon;
    Color color;

    switch (type.toLowerCase()) {
      case 'eligibility':
      case 'eligibility_update':
        label = 'شرایط پذیرش';
        icon = Icons.verified_user_outlined;
        color = AppColors.teal;
        break;
      case 'fee':
      case 'fee_change':
        label = 'هزینه‌ها و مبالغ';
        icon = Icons.payments_outlined;
        color = const Color(0xFFD97706);
        break;
      case 'document':
      case 'process_requirement':
        label = 'مدارک و مراحل';
        icon = Icons.folder_shared_outlined;
        color = AppColors.navy;
        break;
      case 'quota':
      case 'quota_cap':
        label = 'ظرفیت و مهلت';
        icon = Icons.hourglass_top_outlined;
        color = AppColors.primaryRed;
        break;
      default:
        label = 'به‌روزرسانی عمومی';
        icon = Icons.article_outlined;
        color = AppColors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTypeBadge(String type) {
    String label;
    IconData icon;
    Color color;

    switch (type.toLowerCase()) {
      case 'government':
      case 'official_primary':
        label = 'دولتی مهاجرت';
        icon = Icons.account_balance;
        color = AppColors.teal;
        break;
      case 'embassy':
      case 'consulate':
        label = 'سفارت / کنسولگری';
        icon = Icons.flag_outlined;
        color = AppColors.navy;
        break;
      case 'university':
      case 'academic':
        label = 'دانشگاه رسمی';
        icon = Icons.school_outlined;
        color = const Color(0xFF2563EB);
        break;
      case 'professional_body':
        label = 'نظام حرفه‌ای / ارزیابی';
        icon = Icons.workspace_premium_outlined;
        color = const Color(0xFF7C3AED);
        break;
      case 'admin_reference':
      case 'custom':
      default:
        label = 'منبع پیشنهادی مدیر';
        icon = Icons.person_outline;
        color = AppColors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطا در واکشی منبع: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _refreshingAuthorities.remove(authorityId));
      }
    }
  }

  void _showDiscoverDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => const _DiscoverAuthoritiesDialog(),
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
        title: const Text('پایش منابع رسمی، یافته‌های پژوهش و مغایرت‌ها'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'ثبت منبع جدید',
            icon: const Icon(Icons.add_link),
            onPressed: () => showAdminSourceDialog(context),
          ),
          IconButton(
            tooltip: 'شناسایی و کشف مراجع رسمی جدید',
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
            Tab(text: 'یافته‌های پژوهش و تغییرات مغایرت'),
            Tab(text: 'مدیریت مراجع و منابع اطلاعاتی'),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: Research Findings & Proposals Dashboard
          _buildFindingsTab(proposalsAsync),

          // Tab 1: Sources & Authorities Management
          _buildSourcesTab(authoritiesAsync),
        ],
      ),
    );
  }

  Widget _buildFindingsTab(
    AsyncValue<List<AdminSourceChangeProposal>> proposalsAsync,
  ) {
    return proposalsAsync.when(
      loading: () => const Center(child: RadPending()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 40),
              const SizedBox(height: 8),
              Text('خطا در دریافت یافته‌های پژوهش: $err'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(adminProposalsProvider),
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      ),
      data: (proposals) {
        if (proposals.isEmpty) {
          return const Center(child: Text('هیچ تغییر جدیدی یافت نشد.'));
        }
        // Filter proposals
        final filtered = proposals.where((p) {
          if (_findingsCountryFilter != 'all' &&
              p.countryCode.toUpperCase() !=
                  _findingsCountryFilter.toUpperCase()) {
            return false;
          }
          if (_findingsStatusFilter != 'all') {
            final matchStatus = _findingsStatusFilter == 'pending'
                ? SourceProposalReviewStatus.pending
                : _findingsStatusFilter == 'approved'
                ? SourceProposalReviewStatus.approved
                : SourceProposalReviewStatus.rejected;
            if (p.reviewStatus != matchStatus) return false;
          }
          if (_findingsSearchQuery.isNotEmpty) {
            final q = _findingsSearchQuery.toLowerCase();
            final match =
                p.authorityName.toLowerCase().contains(q) ||
                p.summaryOfChanges.toLowerCase().contains(q) ||
                p.pathwaySlug.toLowerCase().contains(q) ||
                p.countryCode.toLowerCase().contains(q);
            if (!match) return false;
          }
          return true;
        }).toList();

        return Column(
          children: [
            // Findings Filters Toolbar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) =>
                              setState(() => _findingsSearchQuery = val),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, size: 18),
                            hintText:
                                'جستجو در عنوان تغییر، کشور یا مرجع استناد...',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text(
                          'کشور:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('همه'),
                          selected: _findingsCountryFilter == 'all',
                          onSelected: (_) =>
                              setState(() => _findingsCountryFilter = 'all'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('🇨🇦 کانادا'),
                          selected: _findingsCountryFilter == 'CA',
                          onSelected: (_) =>
                              setState(() => _findingsCountryFilter = 'CA'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('🇩🇪 آلمان'),
                          selected: _findingsCountryFilter == 'DE',
                          onSelected: (_) =>
                              setState(() => _findingsCountryFilter = 'DE'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('🇦🇺 استرالیا'),
                          selected: _findingsCountryFilter == 'AU',
                          onSelected: (_) =>
                              setState(() => _findingsCountryFilter = 'AU'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('🇬🇧 انگلستان'),
                          selected: _findingsCountryFilter == 'UK',
                          onSelected: (_) =>
                              setState(() => _findingsCountryFilter = 'UK'),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'وضعیت:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('همه وضعیت‌ها'),
                          selected: _findingsStatusFilter == 'all',
                          onSelected: (_) =>
                              setState(() => _findingsStatusFilter = 'all'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('در انتظار بررسی'),
                          selected: _findingsStatusFilter == 'pending',
                          onSelected: (_) =>
                              setState(() => _findingsStatusFilter = 'pending'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('تأییدشده'),
                          selected: _findingsStatusFilter == 'approved',
                          onSelected: (_) => setState(
                            () => _findingsStatusFilter = 'approved',
                          ),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('ردشده'),
                          selected: _findingsStatusFilter == 'rejected',
                          onSelected: (_) => setState(
                            () => _findingsStatusFilter = 'rejected',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Findings List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 48,
                            color: AppColors.teal,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'هیچ یافته یا مغایرت جدیدی مطابق با فیلتر انتخابی وجود ندارد.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (_findingsCountryFilter != 'all' ||
                              _findingsStatusFilter != 'all') ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _findingsCountryFilter = 'all';
                                  _findingsStatusFilter = 'all';
                                  _findingsSearchQuery = '';
                                });
                              },
                              child: const Text('پاک‌سازی فیلترها'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final prop = filtered[index];
                        return _buildFindingCard(prop);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFindingCard(AdminSourceChangeProposal prop) {
    final flag = _flagForCountry(prop.countryCode);
    final hasConflict = prop.factualStatus == FactualStatus.conflicting;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: hasConflict ? AppColors.warning : AppColors.border,
          width: hasConflict ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            prop.authorityName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SourceProvenanceBadge(
                            trustLevel: hasConflict
                                ? SourceTrustLevel.conflicting
                                : SourceTrustLevel.officiallyVerified,
                            fontSize: 10,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'مسیر ویزا: ${prop.countryCode} · ${prop.pathwaySlug.isNotEmpty ? prop.pathwaySlug : 'عمومی'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(prop.reviewStatus),
              ],
            ),
          ),

          // Content Summary
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              prop.summaryOfChanges,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),

          // Evidence Details
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                _buildChangeTypeBadge('eligibility'),
                const SizedBox(width: 8),
                Text(
                  'تاریخ شناسایی: ${prop.detectedAt.toLocal().toString().split(' ').first}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (prop.evidenceUrl.isNotEmpty) ...[
                  const Spacer(),
                  const Icon(Icons.link, size: 14, color: AppColors.primaryRed),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      prop.authorityDomain.isNotEmpty
                          ? prop.authorityDomain
                          : 'مستند رسمی',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryRed,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (hasConflict) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'هشدار: اطلاعات استخراج‌شده با سایر مراجع رسمی ثبت‌شده تناقض دارد.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 20),

          // Action CTA Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تعداد بندهای پیشنهادی: ${prop.changes.isNotEmpty ? prop.changes.length : 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () =>
                      context.go('/admin/sources/${prop.id}/review'),
                  icon: const Icon(Icons.menu_book_outlined, size: 15),
                  label: const Text(
                    'بررسی تطبیقی تمام‌صفحه',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcesTab(AsyncValue<List<Authority>> authoritiesAsync) {
    return authoritiesAsync.when(
      loading: () => const Center(child: RadPending()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 40),
              const SizedBox(height: 8),
              Text('خطا در بارگذاری مراجع رسمی: $err'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(adminAuthoritiesProvider),
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      ),
      data: (authorities) {
        final filtered = authorities.where((auth) {
          if (_sourcesTypeFilter != 'all' &&
              auth.authorityType.toLowerCase() !=
                  _sourcesTypeFilter.toLowerCase()) {
            return false;
          }
          if (_sourcesCountryFilter != 'all' &&
              (auth.countryCode ?? '').toUpperCase() !=
                  _sourcesCountryFilter.toUpperCase()) {
            return false;
          }
          if (_sourcesSearchQuery.isNotEmpty) {
            final q = _sourcesSearchQuery.toLowerCase();
            final match =
                auth.name.toLowerCase().contains(q) ||
                auth.jurisdiction.toLowerCase().contains(q) ||
                auth.officialDomains.any((d) => d.toLowerCase().contains(q));
            if (!match) return false;
          }
          return true;
        }).toList();

        return Column(
          children: [
            // Sources Toolbar & Filters
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) =>
                              setState(() => _sourcesSearchQuery = val),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, size: 18),
                            hintText:
                                'جستجو در نام مرجع، دامنه یا حوزه قضایی...',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () => showAdminSourceDialog(context),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('افزودن منبع'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text(
                          'نوع مرجع:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('همه انواع'),
                          selected: _sourcesTypeFilter == 'all',
                          onSelected: (_) =>
                              setState(() => _sourcesTypeFilter = 'all'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('دولتی مهاجرت'),
                          selected: _sourcesTypeFilter == 'government',
                          onSelected: (_) =>
                              setState(() => _sourcesTypeFilter = 'government'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('سفارتخانه‌ها'),
                          selected: _sourcesTypeFilter == 'embassy',
                          onSelected: (_) =>
                              setState(() => _sourcesTypeFilter = 'embassy'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('دانشگاه‌ها'),
                          selected: _sourcesTypeFilter == 'university',
                          onSelected: (_) =>
                              setState(() => _sourcesTypeFilter = 'university'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('سازمان‌های ارزیابی'),
                          selected: _sourcesTypeFilter == 'professional_body',
                          onSelected: (_) => setState(
                            () => _sourcesTypeFilter = 'professional_body',
                          ),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('سفارشی مدیر'),
                          selected: _sourcesTypeFilter == 'admin_reference',
                          onSelected: (_) => setState(
                            () => _sourcesTypeFilter = 'admin_reference',
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'کشور:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('همه'),
                          selected: _sourcesCountryFilter == 'all',
                          onSelected: (_) =>
                              setState(() => _sourcesCountryFilter = 'all'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('🇨🇦 CA'),
                          selected: _sourcesCountryFilter == 'CA',
                          onSelected: (_) =>
                              setState(() => _sourcesCountryFilter = 'CA'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('🇩🇪 DE'),
                          selected: _sourcesCountryFilter == 'DE',
                          onSelected: (_) =>
                              setState(() => _sourcesCountryFilter = 'DE'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('🇦🇺 AU'),
                          selected: _sourcesCountryFilter == 'AU',
                          onSelected: (_) =>
                              setState(() => _sourcesCountryFilter = 'AU'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Sources List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.source_outlined,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'هیچ منبع یا مرجع اطلاعاتی مطابق با فیلتر انتخابی یافت نشد.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final auth = filtered[index];
                        return _buildAuthorityCard(auth);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAuthorityCard(Authority auth) {
    final isRefreshing = _refreshingAuthorities.contains(auth.id);
    final flag = _flagForCountry(auth.countryCode ?? '');

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
            children: [
              Text(flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
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
              _buildSourceTypeBadge(auth.authorityType),
              const SizedBox(width: 6),
              SourceProvenanceBadge(
                trustLevel: SourceTrustLevel.fromString(auth.verificationState),
                fontSize: 10,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'حوزه قضایی و اعتبار: ${auth.jurisdiction}${auth.countryCode != null ? ' (${auth.countryCode})' : ''}',
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
          if (auth.competenceTopics.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: auth.competenceTopics.map((topic) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    topic,
                    style: const TextStyle(fontSize: 10, color: AppColors.navy),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                auth.verifiedAt != null
                    ? 'تاریخ تأیید اعتبار: ${auth.verifiedAt!.toLocal().toString().split(' ').first}'
                    : 'نیازمند راستی‌آزمایی مستندات',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: isRefreshing
                    ? null
                    : () => _refreshAuthority(auth.id),
                icon: isRefreshing
                    ? const SizedBox(width: 14, height: 14, child: RadPending())
                    : const Icon(Icons.refresh, size: 15),
                label: Text(
                  isRefreshing ? 'در حال ارسال…' : 'واکشی تغییرات منبع',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'حوزه قضایی و اعتبار: ${auth.jurisdiction}${auth.countryCode != null ? ' (${auth.countryCode})' : ''}',
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
          if (auth.competenceTopics.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: auth.competenceTopics.map((topic) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    topic,
                    style: const TextStyle(fontSize: 10, color: AppColors.navy),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                auth.verifiedAt != null
                    ? 'تاریخ تأیید اعتبار: ${auth.verifiedAt!.toLocal().toString().split(' ').first}'
                    : 'نیازمند راستی‌آزمایی مستندات',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: isRefreshing
                    ? null
                    : () => _refreshAuthority(auth.id),
                icon: isRefreshing
                    ? const SizedBox(width: 14, height: 14, child: RadPending())
                    : const Icon(Icons.refresh, size: 15),
                label: Text(
                  isRefreshing ? 'در حال ارسال…' : 'واکشی فوری تغییرات',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _flagForCountry(String code) {
    switch (code.toUpperCase()) {
      case 'CA':
        return '🇨🇦';
      case 'DE':
        return '🇩🇪';
      case 'AU':
        return '🇦🇺';
      case 'UK':
      case 'GB':
        return '🇬🇧';
      case 'US':
        return '🇺🇸';
      default:
        return '🌍';
    }
  }
}

/// Dedicated Discover Authorities Dialog with proper controller disposal (fixes F11).
class _DiscoverAuthoritiesDialog extends ConsumerStatefulWidget {
  const _DiscoverAuthoritiesDialog();

  @override
  ConsumerState<_DiscoverAuthoritiesDialog> createState() =>
      __DiscoverAuthoritiesDialogState();
}

class __DiscoverAuthoritiesDialogState
    extends ConsumerState<_DiscoverAuthoritiesDialog> {
  late final TextEditingController _countryController;
  late final TextEditingController _topicController;
  late final TextEditingController _professionController;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _countryController = TextEditingController(text: 'CA');
    _topicController = TextEditingController(text: 'immigration');
    _professionController = TextEditingController();
  }

  @override
  void dispose() {
    _countryController.dispose();
    _topicController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  Future<void> _discover() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(adminCmsRepositoryProvider);
      await repo.discoverOfficialAuthorities(
        countryCode: _countryController.text.trim(),
        topic: _topicController.text.trim(),
        profession: _professionController.text.trim().isEmpty
            ? null
            : _professionController.text.trim(),
        requestKey: newRadRequestKey(),
      );

      if (!mounted) return;
      nav.pop();
      ref.invalidate(adminAuthoritiesProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('درخواست شناسایی مراجع رسمی جدید با موفقیت ثبت شد.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'خطا در ثبت کاوش: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('شناسایی و کشف مراجع رسمی جدید'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _countryController,
              decoration: const InputDecoration(
                labelText: 'کد کشور (مانند CA, DE, AU)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'موضوع تخصصی (مانند immigration)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _professionController,
              decoration: const InputDecoration(
                labelText: 'حرفه یا تخصص ارزیابی (اختیاری)',
              ),
            ),
            if (_loading) ...[const SizedBox(height: 16), const RadPending()],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: _loading ? null : _discover,
          child: const Text('آغاز کاوش'),
        ),
      ],
    );
  }
}
