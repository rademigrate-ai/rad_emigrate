import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/supabase/rad_contract.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../data/admin_cms_repository.dart';
import '../../data/mock_research_admin_repository.dart';
import '../../domain/entities/admin_cms_entities.dart';
import '../../domain/entities/admin_research_models.dart';
import '../widgets/research_dashboard_view.dart';
import '../widgets/research_history_view.dart';
import '../widgets/source_management_view.dart';
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

final adminDashboardMetricsProvider =
    Provider.autoDispose<ResearchDashboardMetrics>((ref) {
      final repo = ref.watch(adminCmsRepositoryProvider);
      if (repo is MockResearchAdminRepository) {
        return repo.getDashboardMetrics();
      }
      final proposals =
          ref.watch(adminProposalsProvider).valueOrNull ?? const [];
      final authorities =
          ref.watch(adminAuthoritiesProvider).valueOrNull ?? const [];
      return ResearchDashboardMetrics(
        monitoredCountriesCount: authorities
            .map((a) => a.countryCode)
            .whereType<String>()
            .toSet()
            .length,
        activeOfficialSourcesCount: authorities.length,
        employerAddedSourcesCount: 0,
        monitoredUniversitiesCount: authorities
            .where((a) => a.authorityType == 'university')
            .length,
        detectedChangesCount: proposals.length,
        pendingAdminReviewsCount: proposals
            .where((p) => p.reviewStatus == SourceProposalReviewStatus.pending)
            .length,
        monitoringFailuresCount: 0,
        overdueSourceChecksCount: 0,
        lastCrawlCompletedAt: DateTime.now(),
      );
    });

final adminManagedSourcesProvider =
    Provider.autoDispose<List<ManagedResearchSource>>((ref) {
      final repo = ref.watch(adminCmsRepositoryProvider);
      if (repo is MockResearchAdminRepository) {
        return repo.listManagedSources();
      }
      final authorities =
          ref.watch(adminAuthoritiesProvider).valueOrNull ?? const [];
      if (authorities.isEmpty) {
        return const [];
      }
      return authorities.map((auth) {
        final isUni = auth.authorityType == 'university';
        return ManagedResearchSource(
          id: auth.id,
          name: auth.name,
          baseUrl: auth.officialDomains.isNotEmpty
              ? 'https://${auth.officialDomains.first}'
              : 'https://official.gov',
          countryCode: auth.countryCode ?? 'GLOBAL',
          universityName: isUni ? auth.name : null,
          topic: auth.competenceTopics.join('، '),
          relevantArticles: const ['مهاجرت کاری', 'ویزای تحصیلی'],
          verificationTier: isUni
              ? SourceVerificationTier.accreditedUniversity
              : (auth.verificationState == 'verified'
                    ? SourceVerificationTier.officialAuthority
                    : SourceVerificationTier.employerDefinedUnverified),
          isEnabled: true,
          interval: MonitoringInterval.daily,
          lastCheckedAt: auth.verifiedAt ?? DateTime.now(),
          nextScheduledCheckAt: DateTime.now().add(const Duration(hours: 12)),
          connectionStatus: 'ok_200',
        );
      }).toList();
    });

final adminCrawlRunsProvider = Provider.autoDispose<List<CrawlRunHistoryItem>>((
  ref,
) {
  final repo = ref.watch(adminCmsRepositoryProvider);
  if (repo is MockResearchAdminRepository) {
    return repo.listCrawlRuns();
  }
  return const [];
});

final adminSourceSnapshotsProvider =
    Provider.autoDispose<List<SourceSnapshotItem>>((ref) {
      final repo = ref.watch(adminCmsRepositoryProvider);
      if (repo is MockResearchAdminRepository) {
        return repo.listSourceSnapshots();
      }
      return const [];
    });

final adminDecisionHistoryProvider =
    Provider.autoDispose<List<AdminDecisionHistoryItem>>((ref) {
      final repo = ref.watch(adminCmsRepositoryProvider);
      if (repo is MockResearchAdminRepository) {
        return repo.listAdminDecisions();
      }
      return const [];
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
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
    final metrics = ref.watch(adminDashboardMetricsProvider);
    final managedSources = ref.watch(adminManagedSourcesProvider);
    final crawlRuns = ref.watch(adminCrawlRunsProvider);
    final snapshots = ref.watch(adminSourceSnapshotsProvider);
    final decisions = ref.watch(adminDecisionHistoryProvider);

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
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          tabs: const [
            Tab(
              icon: Icon(Icons.policy_outlined, size: 18),
              text: 'پیشنهادهای مغایرت',
            ),
            Tab(
              icon: Icon(Icons.dashboard_outlined, size: 18),
              text: 'داشبورد پایش',
            ),
            Tab(
              icon: Icon(Icons.source_outlined, size: 18),
              text: 'مراجع رسمی و معتبر',
            ),
            Tab(
              icon: Icon(Icons.history_edu_outlined, size: 18),
              text: 'تاریخچه و کپسول‌ها',
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: Screen 3 & 4 Gateway — Research Findings & Proposals
          _buildFindingsTab(proposalsAsync),

          // Tab 1: Screen 1 — Research Dashboard
          _buildDashboardTab(metrics, crawlRuns),

          // Tab 2: Screen 2 — Sources & Authorities Management
          _buildSourcesTab(managedSources),

          // Tab 3: Screen 5 — Research History & Snapshots
          _buildHistoryTab(crawlRuns, snapshots, decisions),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(
    ResearchDashboardMetrics metrics,
    List<CrawlRunHistoryItem> runs,
  ) {
    return ResearchDashboardView(
      metrics: metrics,
      recentRuns: runs,
      onJumpToProposals: () => _tabController.animateTo(0),
      onJumpToSources: () => _tabController.animateTo(2),
      onAddNewSource: () => showAdminSourceDialog(context),
      onTriggerManualCrawl: () async {
        final repo = ref.read(adminCmsRepositoryProvider);
        await repo.enqueueResearchRefresh(
          authorityIds: ['all-active'],
          requestKey: newRadRequestKey(),
        );
        ref.invalidate(adminProposalsProvider);
      },
    );
  }

  Widget _buildHistoryTab(
    List<CrawlRunHistoryItem> runs,
    List<SourceSnapshotItem> snapshots,
    List<AdminDecisionHistoryItem> decisions,
  ) {
    return ResearchHistoryView(
      crawlRuns: runs,
      snapshots: snapshots,
      decisions: decisions,
      onInspectProposal: (propId) =>
          context.go('/admin/sources/$propId/review'),
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
                          Flexible(
                            child: Text(
                              prop.authorityName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
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

  Widget _buildSourcesTab(List<ManagedResearchSource> sources) {
    return SourceManagementView(
      sources: sources,
      onToggleSource: (id) {
        // State is managed in UI view
      },
      onUpdateInterval: (id, interval) {
        // State is managed in UI view
      },
      onRefreshSource: (id) => _refreshAuthority(id),
      onAddNewSource: () => showAdminSourceDialog(context),
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
