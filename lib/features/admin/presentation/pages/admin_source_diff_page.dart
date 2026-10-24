import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../data/admin_cms_repository.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/entities/admin_cms_entities.dart';

class AdminSourceDiffPage extends ConsumerStatefulWidget {
  final String sourceId;

  const AdminSourceDiffPage({super.key, required this.sourceId});

  @override
  ConsumerState<AdminSourceDiffPage> createState() =>
      _AdminSourceDiffPageState();
}

class _AdminSourceDiffPageState extends ConsumerState<AdminSourceDiffPage> {
  late final TextEditingController _notesController;
  bool _isSubmitting = false;
  int _generation = 0;
  int _selectedViewTab = 0; // 0: Section Diff, 1: Evidence, 2: Raw JSON
  late Future<AdminSourceChangeProposal?> _proposal;
  late AdminCmsRepository _repository;
  AdminSourceChangeProposal? _displayedProposal;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _repository = ref.read(adminCmsRepositoryProvider);
    _proposal = _repository.getProposalDetail(widget.sourceId);
  }

  @override
  void didUpdateWidget(covariant AdminSourceDiffPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceId != widget.sourceId) {
      _generation++;
      _notesController.clear();
      _displayedProposal = null;
      _isSubmitting = false;
      _repository = ref.read(adminCmsRepositoryProvider);
      _proposal = _repository.getProposalDetail(widget.sourceId);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitDecision(SourceProposalReviewStatus decision) async {
    final generation = _generation;
    setState(() => _isSubmitting = true);
    final repo = _repository;
    try {
      final proposal = _displayedProposal;
      if (proposal == null) throw const CmsException('unavailable');
      final ok = await repo.reviewProposal(
        proposalId: widget.sourceId,
        expectedRevision: proposal.revision,
        decision: decision,
        reviewerNotes: _notesController.text.trim(),
      );
      if (!mounted || generation != _generation) return;
      if (!ok) throw const CmsException('malformed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == SourceProposalReviewStatus.approved
                ? 'پیشنهاد تأیید و پیش‌نویس ساخته شد؛ منتشر نشده است.'
                : 'پیشنهاد رد شد.',
          ),
        ),
      );
      context.go('/admin/sources');
    } catch (e) {
      if (mounted && generation == _generation) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildOperationBadge(String operation) {
    Color bg;
    Color fg;
    String label;
    switch (operation.toLowerCase()) {
      case 'add':
        bg = AppColors.success.withValues(alpha: 0.12);
        fg = AppColors.success;
        label = 'افزودن بخش جدید';
        break;
      case 'remove':
        bg = AppColors.error.withValues(alpha: 0.12);
        fg = AppColors.error;
        label = 'حذف بخش';
        break;
      case 'replace':
      default:
        bg = AppColors.primaryRed.withValues(alpha: 0.12);
        fg = AppColors.primaryRed;
        label = 'جایگزینی محتوا';
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildSectionDiffCard(SectionChange change) {
    final replacement = change.replacement;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
              Text(
                replacement?.heading ?? 'بخش شناسه: ${change.sectionId.substring(0, 8)}…',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              _buildOperationBadge(change.operation),
            ],
          ),
          if (replacement?.anchor != null) ...[
            const SizedBox(height: 4),
            Text(
              'لنگر: #${replacement!.anchor}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ],
          if (change.beforeHash != null) ...[
            const SizedBox(height: 4),
            Text(
              'هش قبل: ${change.beforeHash!.substring(0, 16)}…',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (replacement != null && replacement.blocks.isNotEmpty) ...[
            const Text(
              'محتوای جدید بخش:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            ...replacement.blocks.map((block) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (block.text.isNotEmpty)
                      Text(
                        block.text,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    if (block.items.isNotEmpty)
                      ...block.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '• $item',
                            style: const TextStyle(fontSize: 12, height: 1.3),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ] else if (change.operation == 'remove') ...[
            const Text(
              'این بخش طبق سند رسمی حذف خواهد شد.',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvidenceCard(EvidenceRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
                  const Icon(Icons.verified, size: 16, color: AppColors.teal),
                  const SizedBox(width: 6),
                  Text(
                    ref.publisher,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ref.sourceClass,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ref.url,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.primaryRed,
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(6),
              border: const Border(
                right: BorderSide(color: AppColors.teal, width: 3),
              ),
            ),
            child: Text(
              '«${ref.excerpt}»',
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'وضعیت راستی‌آزمایی: ${ref.verificationState.toDisplayPersian()}',
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                'تازگی: ${ref.freshnessState}',
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authenticatedUserIdProvider, (previous, next) {
      if (previous == next) return;
      setState(() {
        _generation++;
        _isSubmitting = false;
        _notesController.clear();
        _displayedProposal = null;
        _repository = ref.read(adminCmsRepositoryProvider);
        _proposal = _repository.getProposalDetail(widget.sourceId);
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/admin/sources'),
        title: const Text('بررسی تغییرات منبع رسمی'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<AdminSourceChangeProposal?>(
        future: _proposal,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: RadPending());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final proposal = snapshot.data;
          _displayedProposal = proposal;
          if (proposal == null) {
            return const Center(child: Text('پیشنهاد مورد نظر یافت نشد.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Authority Metadata Header
              Container(
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
                        const Icon(
                          Icons.verified_user,
                          color: AppColors.teal,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          proposal.authorityName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'دامنه رسمی: ${proposal.authorityDomain}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'پیوند استناد اصلی: ${proposal.evidenceUrl}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryRed,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Segmented View Selector
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('تغییرات بخش‌ها'),
                    selected: _selectedViewTab == 0,
                    onSelected: (_) => setState(() => _selectedViewTab = 0),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('شواهد و مدارک (${proposal.evidence.length})'),
                    selected: _selectedViewTab == 1,
                    onSelected: (_) => setState(() => _selectedViewTab = 1),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('کد خام JSON'),
                    selected: _selectedViewTab == 2,
                    onSelected: (_) => setState(() => _selectedViewTab = 2),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tab Content
              if (_selectedViewTab == 0) ...[
                if (proposal.changes.isNotEmpty)
                  ...proposal.changes.map(_buildSectionDiffCard)
                else ...[
                  // Fallback to previous vs proposed text boxes
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.remove_circle_outline,
                              color: AppColors.error,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'متن قبلی مقاله در سیستم:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          proposal.previousText,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.add_circle_outline,
                              color: AppColors.success,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'متن جدید استخراج‌شده از منبع رسمی:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          proposal.proposedText,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else if (_selectedViewTab == 1) ...[
                if (proposal.evidence.isNotEmpty)
                  ...proposal.evidence.map(_buildEvidenceCard)
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('شواهد مستقیمی ثبت نشده است.')),
                  ),
              ] else ...[
                // Raw JSON Inspector
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: SelectableText(
                    proposal.proposedText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Human Review Decision Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'بررسی انسانی پیشنهاد',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'توجه: تأیید پیشنهاد صرفاً یک پیش‌نویس (Draft) غیرمنتشر در CMS ایجاد می‌کند و به هیچ وجه مقاله را به‌صورت خودکار منتشر نمی‌سازد.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'یادداشت بازبین سردبیری (اختیاری)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Decision actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.error),
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () => _submitDecision(
                                SourceProposalReviewStatus.rejected,
                              ),
                      child: const Text(
                        'رد تغییرات',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () => _submitDecision(
                                SourceProposalReviewStatus.approved,
                              ),
                      child: const Text('تأیید و ایجاد پیش‌نویس'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
