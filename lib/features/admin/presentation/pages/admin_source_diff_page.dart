import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../../visa/domain/entities/search_entities.dart';
import '../../data/admin_cms_repository.dart';
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
  FactualStatus _selectedFactualStatus = FactualStatus.verified;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitDecision(SourceProposalReviewStatus decision) async {
    setState(() => _isSubmitting = true);
    final repo = ref.read(adminCmsRepositoryProvider);
    final ok = await repo.reviewProposal(
      proposalId: widget.sourceId,
      decision: decision,
      factualStatus: _selectedFactualStatus,
      reviewerNotes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == SourceProposalReviewStatus.approved
                  ? 'تغییرات با موفقیت تأیید و در مقاله تجمیعی ادغام شد.'
                  : 'پیشنهاد با موفقیت رد شد.',
            ),
          ),
        );
        context.go('/admin/sources');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(adminCmsRepositoryProvider);

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
        future: repo.getProposalDetail(widget.sourceId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: RadPending());
          }
          final proposal = snapshot.data;
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
                      'تعیین وضعیت حقیقت رسمی (Factual Status)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<FactualStatus>(
                      initialValue: _selectedFactualStatus,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: FactualStatus.values.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s.toDisplayPersian()),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedFactualStatus = v);
                        }
                      },
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
                      child: const Text('تأیید و اعمال در مقاله تجمیعی'),
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
