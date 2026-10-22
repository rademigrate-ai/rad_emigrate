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

              // Visual Diff Comparison: Previous vs New
              const Text(
                'مقایسه متن پیشین با تغییرات کشف‌شده جدید',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 10),

              // Previous text box (red tint)
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

              // Proposed text box (green tint)
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
              const SizedBox(height: 16),

              // Factual status decision dropdown
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
                    const SizedBox(height: 10),
                    const Text(
                      'این بررسی، وضعیت رسمی شواهد یا انتشار مقاله را تغییر نمی‌دهد.',
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
