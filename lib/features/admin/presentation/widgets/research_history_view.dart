import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../domain/entities/admin_research_models.dart';

/// Screen 5 — Research Assistant History, Snapshots Archive & Editorial Audit Log.
class ResearchHistoryView extends StatefulWidget {
  final List<CrawlRunHistoryItem> crawlRuns;
  final List<SourceSnapshotItem> snapshots;
  final List<AdminDecisionHistoryItem> decisions;
  final ValueChanged<String>? onInspectProposal;

  const ResearchHistoryView({
    super.key,
    required this.crawlRuns,
    required this.snapshots,
    required this.decisions,
    this.onInspectProposal,
  });

  @override
  State<ResearchHistoryView> createState() => _ResearchHistoryViewState();
}

class _ResearchHistoryViewState extends State<ResearchHistoryView>
    with SingleTickerProviderStateMixin {
  late final TabController _innerTabController;

  @override
  void initState() {
    super.initState();
    _innerTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _innerTabController.dispose();
    super.dispose();
  }

  void _showSnapshotDetailModal(SourceSnapshotItem snap) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.archive_outlined, color: AppColors.navy, size: 20),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'کپسول تصویر لحظه‌ای منبع (Source Snapshot)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('شناسه کپسول:', snap.snapshotId),
                  _buildDetailRow('مرجع حقوقی:', snap.authorityName),
                  _buildDetailRow('آدرس رسمی:', snap.url),
                  _buildDetailRow('زمان استخراج:', '${snap.fetchedAt.toLocal()}'),
                  _buildDetailRow('هش محتوا (SHA-256):', snap.contentHash, isMono: true),
                  _buildDetailRow('حجم داده دریافتی:', '${snap.byteSize} بایت (وضعیت: ${snap.httpStatusCode} OK)'),
                  const SizedBox(height: 12),
                  const Text(
                    'متن خام و استخراج‌شده از منبع رسمی:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SelectableText(
                      snap.excerpt,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('بستن'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 11,
                fontFamily: isMono ? 'monospace' : null,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Sub-TabBar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _innerTabController,
            labelColor: AppColors.primaryRed,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryRed,
            tabs: const [
              Tab(icon: Icon(Icons.history, size: 16), text: 'دوره‌های پویش (Crawl Runs)'),
              Tab(icon: Icon(Icons.archive, size: 16), text: 'آرشیو تصاویر مراجع (Snapshots)'),
              Tab(icon: Icon(Icons.gavel, size: 16), text: 'تصمیمات سردبیری (Audit Log)'),
            ],
          ),
        ),

        const Divider(height: 1),

        // Sub-TabBar Views
        Expanded(
          child: TabBarView(
            controller: _innerTabController,
            children: [
              // 1. Crawl Runs History
              _buildCrawlRunsList(),

              // 2. Source Snapshots Archive
              _buildSnapshotsList(),

              // 3. Editorial Decisions Audit Log
              _buildDecisionsList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCrawlRunsList() {
    if (widget.crawlRuns.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_toggle_off, size: 48, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text(
                'هیچ دوره پویشی در سرور ثبت نشده است.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.crawlRuns.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final run = widget.crawlRuns[index];
        final isSuccess = run.status == 'completed';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSuccess
                      ? AppColors.teal.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.cloud_done : Icons.cloud_sync,
                  color: isSuccess ? AppColors.teal : AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'پویش شماره ${run.runId}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.navy),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSuccess
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            isSuccess ? 'تکمیل‌شده' : 'دارای خطای جزئی',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSuccess ? AppColors.success : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'شروع: ${run.startedAt.toLocal()} • مدت زمان پویش: ${run.duration.inMinutes} دقیقه و ${run.duration.inSeconds % 60} ثانیه',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${run.sourcesScanned} منبع بررسی شد',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${run.changesFound} تغییر جدید • ${run.failuresCount} شکست',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: run.changesFound > 0 ? AppColors.primaryRed : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSnapshotsList() {
    if (widget.snapshots.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.archive_outlined, size: 48, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text(
                'هیچ تصویر لحظه‌ای از مراجع رسمی ذخیره نشده است.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.snapshots.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final snap = widget.snapshots[index];

        return Container(
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
                children: [
                  const Icon(Icons.file_present_outlined, color: AppColors.navy, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      snap.authorityName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.navy),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => _showSnapshotDetailModal(snap),
                    icon: const Icon(Icons.visibility, size: 14),
                    label: const Text('مشاهده جزئیات کپسول', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                snap.url,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  snap.excerpt,
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'زمان ثبت: ${snap.fetchedAt.toLocal()}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                  Text(
                    'هش: ${snap.contentHash.substring(0, 16)}...',
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDecisionsList() {
    if (widget.decisions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gavel_outlined, size: 48, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text(
                'هیچ تصمیم سردبیری ثبت نشده است.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.decisions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final dec = widget.decisions[index];

        Color badgeColor;
        String badgeLabel;
        IconData badgeIcon;

        switch (dec.decision) {
          case 'approved':
            badgeColor = AppColors.teal;
            badgeLabel = 'تأیید شد';
            badgeIcon = Icons.check_circle;
            break;
          case 'edited_and_approved':
            badgeColor = AppColors.navy;
            badgeLabel = 'با ویرایش تأیید شد';
            badgeIcon = Icons.edit_note;
            break;
          case 'rejected':
          default:
            badgeColor = AppColors.error;
            badgeLabel = 'رد شد';
            badgeIcon = Icons.cancel;
            break;
        }

        return Container(
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
                children: [
                  Icon(badgeIcon, color: badgeColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dec.articleTitle,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.navy),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'بازبین: ${dec.reviewerName} • تاریخ: ${dec.reviewedAt.toLocal()}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  'یادداشت سردبیری: ${dec.reviewerNotes}',
                  style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.navy),
                ),
              ),
              if (dec.resultingRevisionHash.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'هش پیش‌نویس نگارش مصوب: ${dec.resultingRevisionHash.substring(0, 24)}...',
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.teal),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
