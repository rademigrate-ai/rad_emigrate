import 'package:flutter/material.dart';
import 'package:rad_emigrate/core/widgets/rad_flapping_bird.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../domain/entities/admin_research_models.dart';

/// Screen 1 — Persian RTL Research Assistant Administrative Dashboard.
class ResearchDashboardView extends StatefulWidget {
  final ResearchDashboardMetrics metrics;
  final List<CrawlRunHistoryItem> recentRuns;
  final bool monitoringHistoryAvailable;
  final VoidCallback? onJumpToProposals;
  final VoidCallback? onJumpToSources;
  final VoidCallback? onAddNewSource;
  final Future<void> Function()? onTriggerManualCrawl;
  final Future<void> Function()? onRetryFailedSources;

  const ResearchDashboardView({
    super.key,
    required this.metrics,
    required this.recentRuns,
    this.monitoringHistoryAvailable = true,
    this.onJumpToProposals,
    this.onJumpToSources,
    this.onAddNewSource,
    this.onTriggerManualCrawl,
    this.onRetryFailedSources,
  });

  @override
  State<ResearchDashboardView> createState() => _ResearchDashboardViewState();
}

class _ResearchDashboardViewState extends State<ResearchDashboardView> {
  bool _isCrawling = false;
  bool _isRetryingFailures = false;

  Future<void> _handleManualCrawl() async {
    if (_isCrawling || widget.onTriggerManualCrawl == null) return;
    setState(() => _isCrawling = true);
    try {
      await widget.onTriggerManualCrawl!();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'پویش دستی مراجع رسمی با موفقیت آغاز شد و در صف پردازش قرار گرفت.',
            ),
            backgroundColor: AppColors.teal,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ثبت درخواست پویش انجام نشد. دوباره تلاش کنید.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCrawling = false);
    }
  }

  Future<void> _handleRetryFailures() async {
    if (_isRetryingFailures || widget.onRetryFailedSources == null) return;
    setState(() => _isRetryingFailures = true);
    try {
      await widget.onRetryFailedSources!();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('درخواست تلاش مجدد در صف پردازش قرار گرفت.'),
            backgroundColor: AppColors.navy,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ثبت درخواست تلاش مجدد انجام نشد.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRetryingFailures = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final isMedium =
            constraints.maxWidth >= 600 && constraints.maxWidth < 900;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // 1. Dashboard Header & Quick Action Buttons
            _buildHeaderActions(isWide),

            const SizedBox(height: 20),

            // 2. Monitoring Failures & Overdue Alert Banner (if any)
            if ((widget.metrics.monitoringFailuresCount ?? 0) > 0 ||
                (widget.metrics.overdueSourceChecksCount ?? 0) > 0) ...[
              _buildAlertBanner(),
              const SizedBox(height: 20),
            ],

            // 3. 8-Key Metrics Overview Grid
            _buildMetricsGrid(isWide, isMedium),

            const SizedBox(height: 24),

            // 4. Monitored Countries & Authorities Spotlight
            _buildCountriesSpotlight(isWide),

            const SizedBox(height: 24),

            // 5. Recent Crawl & Research Activity Runs Summary
            _buildRecentActivitySection(),

            const SizedBox(height: 24),

            // 6. Security Assurance & Human In-the-Loop Footer Notice
            _buildSecurityNotice(),
          ],
        );
      },
    );
  }

  Widget _buildHeaderActions(bool isWide) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.travel_explore,
                    color: AppColors.primaryRed,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'داشبورد هوشمند پایش و دستیار پژوهش',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'دیده‌بانی خودکار مراجع دولتی مهاجرت، سفارت‌ها و پورتال‌های رسمی دانشگاه‌ها',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onPressed: widget.onAddNewSource,
                icon: const Icon(Icons.add_link, size: 16),
                label: const Text('ثبت مرجع جدید'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed: _isCrawling || widget.onTriggerManualCrawl == null
                    ? null
                    : _handleManualCrawl,
                icon: _isCrawling
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: RadFlappingBird(size: 14, showAura: false),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: Text(
                  _isCrawling ? 'در حال پویش مراجع...' : 'پویش دستی فوری',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'هشدار اتصال و بررسی مراجع رسمی',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.metrics.monitoringFailuresCount} مرجع به دلیل خطای اتصال (Timeout یا HTTP 503) با شکست مواجه شده و ${widget.metrics.overdueSourceChecksCount} مرجع از موعد مقرر بررسی عبور کرده‌اند.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed:
                _isRetryingFailures || widget.onRetryFailedSources == null
                ? null
                : _handleRetryFailures,
            icon: _isRetryingFailures
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: RadFlappingBird(size: 12, showAura: false),
                  )
                : const Icon(Icons.sync_problem, size: 14),
            label: const Text('تلاش مجدد مراجع ناموفق'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(bool isWide, bool isMedium) {
    final columns = isWide ? 4 : (isMedium ? 2 : 1);

    final cards = [
      _MetricCard(
        title: 'کشورهای مراجع ثبت‌شده',
        value: widget.metrics.monitoredCountriesCount?.toString() ?? 'نامشخص',
        subtitle: 'بر پایه فهرست مراجع سرور',
        icon: Icons.public,
        color: AppColors.navy,
      ),
      _MetricCard(
        title: 'مراجع تأییدشده ثبت‌شده',
        value:
            widget.metrics.activeOfficialSourcesCount?.toString() ?? 'نامشخص',
        subtitle: 'ادارات دولتی مهاجرت و کنسولگری‌ها',
        icon: Icons.verified_user,
        color: AppColors.teal,
        onTap: widget.onJumpToSources,
      ),
      _MetricCard(
        title: 'منابع افزوده‌شده کارفرما',
        value: widget.metrics.employerAddedSourcesCount?.toString() ?? 'نامشخص',
        subtitle: 'دارای نشان صریح تأییدنشده (Admin Defined)',
        icon: Icons.person_add_alt_1,
        color: AppColors.warning,
        badgeLabel: 'نیازمند احراز صلاحیت',
        onTap: widget.onJumpToSources,
      ),
      _MetricCard(
        title: 'دانشگاه‌های تأییدشده',
        value:
            widget.metrics.monitoredUniversitiesCount?.toString() ?? 'نامشخص',
        subtitle: 'پورتال‌های رسمی ادمیشن بین‌المللی',
        icon: Icons.school,
        color: AppColors.navy,
      ),
      _MetricCard(
        title: 'تغییرات محتوایی مکشوفه',
        value: widget.metrics.detectedChangesCount?.toString() ?? 'نامشخص',
        subtitle: 'تغییرات استخراج‌شده از منابع معتبر',
        icon: Icons.change_circle_outlined,
        color: AppColors.primaryRed,
        onTap: widget.onJumpToProposals,
      ),
      _MetricCard(
        title: 'پیشنهادهای در انتظار بررسی',
        value: widget.metrics.pendingAdminReviewsCount?.toString() ?? 'نامشخص',
        subtitle: 'نیازمند تصمیم و تأیید سردبیر',
        icon: Icons.pending_actions,
        color: AppColors.primaryRed,
        isHighlight: true,
        actionLabel: 'مشاهده و بررسی (کلیک کنید)',
        onTap: widget.onJumpToProposals,
      ),
      _MetricCard(
        title: 'خطاهای پایش و اتصال',
        value: widget.metrics.monitoringFailuresCount?.toString() ?? 'نامشخص',
        subtitle: 'وقفه‌های زمانی و خطاهای HTTP',
        icon: Icons.error_outline,
        color: AppColors.error,
        badgeLabel: 'نیازمند رفع انسداد',
      ),
      _MetricCard(
        title: 'بررسی‌های معوق (Overdue)',
        value: widget.metrics.overdueSourceChecksCount?.toString() ?? 'نامشخص',
        subtitle: 'عبور از فواصل پایش تعیین‌شده',
        icon: Icons.schedule,
        color: AppColors.warning,
      ),
    ];

    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: isWide ? 1.7 : 2.0,
      children: cards,
    );
  }

  Widget _buildCountriesSpotlight(bool isWide) {
    return const Padding(
      padding: EdgeInsets.all(18),
      child: Text('جزئیات پایش کشورها تا دریافت گزارش معتبر سرور نامشخص است.'),
    );
  }

  Widget _buildRecentActivitySection() {
    return Container(
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
              const Icon(Icons.history, color: AppColors.navy, size: 20),
              const SizedBox(width: 8),
              const Text(
                'آخرین دوره‌های پویش و استخراج دستیار پژوهش',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.recentRuns.isEmpty)
            Text(
              widget.monitoringHistoryAvailable
                  ? 'هیچ رویداد پویشی ثبت نشده است.'
                  : 'تاریخچه پایش در دسترس نیست.',
            )
          else
            ...widget.recentRuns.map((run) {
              final isSuccess = run.status == 'completed';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSuccess ? Icons.check_circle : Icons.error,
                      color: isSuccess ? AppColors.teal : AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'دوره پویش ${run.runId} — ${run.sourcesScanned} منبع پایش شد',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    Text(
                      '${run.changesFound} تغییر جدید • مدت: ${run.duration.inMinutes} دقیقه',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.security, color: AppColors.teal, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'تضمین حاکمیت سردبیری: دستیار پژوهش منحصراً به کشف تغییرات در مراجع رسمی و پیشنهاد اصلاحات به تفکیک بند می‌پردازد. هیچ تغییری تا زمان تأیید صریح سردبیر انسانی در قالب پیش‌نویس (Draft) ذخیره نمی‌گردد و انتشار نهایی نیازمند اقدام رسمی مجزاست.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? badgeLabel;
  final String? actionLabel;
  final bool isHighlight;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.badgeLabel,
    this.actionLabel,
    this.isHighlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isHighlight ? color.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: isHighlight
                ? color.withValues(alpha: 0.4)
                : AppColors.border,
            width: isHighlight ? 1.5 : 1,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badgeLabel != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      badgeLabel!,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      actionLabel!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
