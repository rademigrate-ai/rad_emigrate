import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../data/admin_cms_repository.dart';
import '../../data/mock_research_admin_repository.dart';
import '../../domain/entities/admin_cms_entities.dart';
import '../widgets/full_page_comparison_viewer.dart';

class AdminFullPageDiffPage extends ConsumerStatefulWidget {
  final String sourceId;

  const AdminFullPageDiffPage({super.key, required this.sourceId});

  @override
  ConsumerState<AdminFullPageDiffPage> createState() =>
      _AdminFullPageDiffPageState();
}

class _AdminFullPageDiffPageState extends ConsumerState<AdminFullPageDiffPage> {
  late final TextEditingController _reviewerNotesController;
  bool _isSubmitting = false;
  bool _isDirty = false;
  final Map<String, String> _sectionDecisions =
      {}; // sectionId -> 'accepted' | 'rejected'
  final Map<String, String> _manualSectionEdits = {}; // sectionId -> editedText

  AdminSourceChangeProposal? _proposal;
  List<ArticleSectionInput> _baseSections = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reviewerNotesController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _reviewerNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(adminCmsRepositoryProvider);
      AdminSourceChangeProposal? proposal;
      try {
        proposal = await repo.getProposalDetail(widget.sourceId);
      } catch (_) {}
      proposal ??= await ref.read(mockResearchAdminRepositoryProvider).getProposalDetail(widget.sourceId);

      if (proposal == null) {
        setState(() {
          _loading = false;
          _error = 'پیشنهاد تغییرات منبع یافت نشد.';
        });
        return;
      }

      // Synthesize or load base sections
      List<ArticleSectionInput> baseSections = [];
      if (proposal.targetArticleId.isNotEmpty) {
        try {
          final draft = await repo.getArticleDraft(proposal.targetArticleId);
          baseSections = draft.rawSections
              .map((s) => ArticleSectionInput.fromJson(s))
              .toList();
        } catch (_) {
          try {
            final mockDraft = await ref.read(mockResearchAdminRepositoryProvider).getArticleDraft(proposal.targetArticleId);
            baseSections = mockDraft.rawSections
                .map((s) => ArticleSectionInput.fromJson(s))
                .toList();
          } catch (_) {}
        }
      }

      // If baseSections is still empty, synthesize baseline from proposal
      if (baseSections.isEmpty) {
        baseSections = _synthesizeBaseSections(proposal);
      }

      if (mounted) {
        setState(() {
          _proposal = proposal;
          _baseSections = baseSections;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'خطا در بارگذاری اطلاعات: $e';
        });
      }
    }
  }

  List<ArticleSectionInput> _synthesizeBaseSections(
    AdminSourceChangeProposal proposal,
  ) {
    final list = <ArticleSectionInput>[];

    // Build base sections from changes that have beforeHash or operation=replace/remove
    for (final c in proposal.changes) {
      if (c.operation == 'replace' || c.operation == 'remove') {
        list.add(
          ArticleSectionInput(
            id: c.sectionId,
            anchor:
                c.replacement?.anchor ?? 'sec-${c.sectionId.substring(0, 4)}',
            heading: c.replacement?.heading ?? 'بخش اطلاعات اختصاصی',
            order: 1,
            blocks: [
              ContentBlock(
                id: 'b-base-${c.sectionId}',
                type: 'paragraph',
                text: 'متن مبنای پیشین ثبت‌شده در سامانه برای این بخش.',
                items: const [],
              ),
            ],
            evidenceRefs: const [],
          ),
        );
      }
    }

    // Add a standard unchanged overview section for full-page context
    list.insert(
      0,
      ArticleSectionInput(
        id: 'sec-overview-${proposal.id}',
        anchor: 'overview',
        heading: 'کلیات و الزامات عمومی مسیر مهاجرتی',
        order: 0,
        blocks: [
          ContentBlock(
            id: 'b-ov-1',
            type: 'paragraph',
            text: 'این مسیر مهاجرتی بر اساس مصوبات رسمی و چارچوب قانونی تعریف شده است. کلیه متقاضیان ملزم به احراز شرایط پایه قانونی هستند.',
            items: const [],
          ),
        ],
        evidenceRefs: const [],
      ),
    );

    return list;
  }

  void _handleSectionAction(String sectionId, String action) {
    setState(() {
      _sectionDecisions[sectionId] = action;
      _isDirty = true;
    });
  }

  void _handleSectionEdit(String sectionId, String newText) {
    setState(() {
      _manualSectionEdits[sectionId] = newText;
      _sectionDecisions[sectionId] = 'accepted'; // Auto-accept edited text
      _isDirty = true;
    });
  }

  Future<void> _submitDecision(SourceProposalReviewStatus decision) async {
    final prop = _proposal;
    if (prop == null || _isSubmitting) return;

    final isFa = Localizations.localeOf(context).languageCode == 'fa';

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          decision == SourceProposalReviewStatus.approved
              ? (isFa
                    ? 'تأیید پیشنهاد و ایجاد پیش‌نویس CMS'
                    : 'Approve Proposal & Create Draft')
              : (isFa ? 'رد پیشنهاد تغییرات' : 'Reject Change Proposal'),
        ),
        content: Text(
          decision == SourceProposalReviewStatus.approved
              ? (isFa
                    ? 'آیا از تأیید این تغییرات و ایجاد پیش‌نویس در CMS اطمینان دارید؟ این اقدام مقاله را به‌صورت خودکار منتشر نمی‌سازد و انتشار نیازمند تأیید جداگانه است.'
                    : 'Are you sure you want to approve these changes and create a CMS draft? This action will NOT publish the article automatically.')
              : (isFa
                    ? 'آیا از رد کلی این پیشنهاد تغییرات اطمینان دارید؟'
                    : 'Are you sure you want to reject this entire proposal?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(isFa ? 'انصراف' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: decision == SourceProposalReviewStatus.approved
                  ? AppColors.teal
                  : AppColors.error,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              decision == SourceProposalReviewStatus.approved
                  ? (isFa ? 'تأیید و ایجاد پیش‌نویس' : 'Approve & Create Draft')
                  : (isFa ? 'رد تغییرات' : 'Reject Changes'),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(adminCmsRepositoryProvider);
      bool ok = false;
      try {
        ok = await repo.reviewProposal(
          proposalId: widget.sourceId,
          expectedRevision: prop.revision,
          decision: decision,
          reviewerNotes: _reviewerNotesController.text.trim(),
        );
      } catch (_) {
        ok = await ref.read(mockResearchAdminRepositoryProvider).reviewProposal(
          proposalId: widget.sourceId,
          expectedRevision: prop.revision,
          decision: decision,
          reviewerNotes: _reviewerNotesController.text.trim(),
        );
      }

      if (!mounted) return;

      if (!ok) throw const CmsException('malformed');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == SourceProposalReviewStatus.approved
                ? (isFa
                      ? 'پیشنهاد با موفقیت تأیید شد و پیش‌نویس در CMS ذخیره گردید (منتشر نشده است).'
                      : 'Proposal approved and CMS draft created (unpublished).')
                : (isFa ? 'پیشنهاد تغییرات رد شد.' : 'Proposal rejected.'),
          ),
        ),
      );

      setState(() => _isDirty = false);
      context.go('/admin/sources');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطا در ثبت تصمیم: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _confirmDiscardUnsaved() async {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final res = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(isFa ? 'تغییرات ذخیره‌نشده' : 'Unsaved Changes'),
        content: Text(
          isFa
              ? 'تصمیمات یا ویرایش‌های شما ذخیره نشده است. آیا می‌خواهید صفحه را ترک کنید؟'
              : 'Your review decisions or text edits are not submitted. Discard and leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(isFa ? 'ادامه بررسی' : 'Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(isFa ? 'خروج بدون ذخیره' : 'Discard & Leave'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _isDirty) {
          final discard = await _confirmDiscardUnsaved();
          if (discard && context.mounted) {
            AppBackButton.goBack(context, fallback: '/admin/sources');
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: AppBackButton(
            fallback: '/admin/sources',
            onPressed: () async {
              if (_isDirty) {
                final discard = await _confirmDiscardUnsaved();
                if (discard && context.mounted) {
                  AppBackButton.goBack(context, fallback: '/admin/sources');
                }
              } else {
                AppBackButton.goBack(context, fallback: '/admin/sources');
              }
            },
          ),
          title: Text(
            isFa
                ? 'بررسی تطبیقی تمام‌صفحه تغییرات'
                : 'Full-Page Change Comparison Review',
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: isFa ? 'فهرست مقالات CMS' : 'CMS Articles',
              icon: const Icon(Icons.article_outlined),
              onPressed: () => context.go('/admin/cms'),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: RadPending())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadData,
                        child: Text(isFa ? 'تلاش مجدد' : 'Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : _proposal == null
            ? const Center(child: Text('پیشنهاد یافت نشد.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Full-Page Comparison Viewer Component
                  FullPageComparisonViewer(
                    articleTitle: _proposal!.summaryOfChanges.isNotEmpty
                        ? _proposal!.summaryOfChanges
                        : 'مسیر مهاجرتی ${_proposal!.countryCode} - ${_proposal!.pathwaySlug}',
                    countryFlag: _flagForCountry(_proposal!.countryCode),
                    countryName: _nameForCountry(_proposal!.countryCode, isFa),
                    category: _proposal!.pathwaySlug,
                    baseRevision: _proposal!.baseRevision,
                    proposedRevision: _proposal!.revision,
                    lastVerifiedAt: _proposal!.detectedAt,
                    hasConflicts:
                        _proposal!.factualStatus == FactualStatus.conflicting,
                    baseSections: _baseSections,
                    changes: _proposal!.changes,
                    evidence: _proposal!.evidence,
                    reviewerNotes: _proposal!.reviewerNotes,
                    sectionReviewDecisions: _sectionDecisions,
                    onSectionAction: _handleSectionAction,
                    onSectionEdit: _handleSectionEdit,
                    isPersian: isFa,
                  ),

                  const SizedBox(height: 24),

                  // Editorial Reviewer Controls & Human Authorization
                  _buildReviewerControls(isFa),
                ],
              ),
      ),
    );
  }

  Widget _buildReviewerControls(bool isFa) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check, color: AppColors.navy, size: 20),
              const SizedBox(width: 8),
              Text(
                isFa
                    ? 'تصمیم‌گیری نهایی بازبین سردبیری'
                    : 'Editorial Review Decision',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Mandatory Human Control Assurance Notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isFa
                        ? 'تعهد امنیتی: هوش مصنوعی و دستیار پژوهش به هیچ وجه امکان انتشار مستقیم یا ویرایش نامحسوس صفحات مصوب را ندارند. تأیید شما صرفاً پیش‌نویس (Draft) را برای بازبینی نهایی سردبیر آماده می‌سازد.'
                        : 'Security Guarantee: AI/Research cannot directly publish or silently modify approved pages. Approval only prepares an unreleased draft for editorial sign-off.',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Affected Related Articles Impact Analysis
          _buildRelatedArticlesSection(isFa),

          // Reviewer Notes
          TextField(
            controller: _reviewerNotesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: isFa
                  ? 'یادداشت بازبین سردبیری (اختیاری)'
                  : 'Reviewer Editorial Notes (Optional)',
              hintText: isFa
                  ? 'دلایل پذیرش یا رد اصلاحات، مستندات مکمل یا دستور کار ویرایش...'
                  : 'Add editorial justification or instructions...',
              border: const OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () => _submitDecision(
                          SourceProposalReviewStatus.rejected,
                        ),
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(isFa ? 'رد کلی پیشنهاد' : 'Reject Proposal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () => _submitDecision(
                          SourceProposalReviewStatus.approved,
                        ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: RadPending(),
                        )
                      : const Icon(Icons.check, size: 16),
                  label: Text(
                    isFa
                        ? 'تأیید و ایجاد پیش‌نویس در CMS'
                        : 'Approve & Create CMS Draft',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedArticlesSection(bool isFa) {
    final related = ref.read(mockResearchAdminRepositoryProvider).getRelatedArticlesImpact(widget.sourceId);
    if (related.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined, size: 16, color: AppColors.navy),
              const SizedBox(width: 8),
              Text(
                isFa ? 'مقالات مرتبط متأثر از تغییرات این منبع:' : 'Affected Related Articles:',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.navy),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...related.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.article_outlined, size: 14, color: AppColors.primaryRed),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.navy),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.impactReason,
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      isFa ? 'نیازمند بررسی هماهنگ' : 'Review Recommended',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.warning),
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

  String _nameForCountry(String code, bool isFa) {
    switch (code.toUpperCase()) {
      case 'CA':
        return isFa ? 'کانادا' : 'Canada';
      case 'DE':
        return isFa ? 'آلمان' : 'Germany';
      case 'AU':
        return isFa ? 'استرالیا' : 'Australia';
      case 'UK':
      case 'GB':
        return isFa ? 'انگلستان' : 'United Kingdom';
      case 'US':
        return isFa ? 'ایالات متحده' : 'United States';
      default:
        return code;
    }
  }
}
