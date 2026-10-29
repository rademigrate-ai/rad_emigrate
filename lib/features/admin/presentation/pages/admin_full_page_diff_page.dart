import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../data/admin_cms_repository.dart';
import '../../data/research_review_repository.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../domain/entities/admin_cms_entities.dart';
import '../widgets/full_page_comparison_viewer.dart';
import '../widgets/structured_review_viewer.dart';
import '../../../visa/presentation/widgets/editorial_rich_block.dart';

/// Reads the *current* authenticated actor on every call. Tests override the
/// reader with a fixture; production always checks the live Supabase session.
final adminResearchActorReaderProvider = Provider<String? Function()>((ref) {
  final service = ref.watch(supabaseClientServiceProvider);
  return () =>
      service.isInitialized ? service.client.auth.currentUser?.id : null;
});

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
  Map<String, dynamic>? _reviewContext;
  String? _owner;
  List<ArticleSectionInput> _baseSections = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reviewerNotesController = TextEditingController();
    _owner = ref.read(adminResearchActorReaderProvider)();
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
      final context = await ref
          .read(researchReviewRepositoryProvider)
          .context(widget.sourceId);
      final proposal = AdminSourceChangeProposal.fromJson(
        Map<String, dynamic>.from(context['proposal'] as Map),
      );
      if (proposal.changes.length !=
          ((context['proposal'] as Map)['changes'] as List).length) {
        throw const CmsException('malformed');
      }
      final base = context['base'] as Map;
      final baseSections = ((base['body'] as Map)['sections'] as List)
          .map(
            (s) => ArticleSectionInput.fromJson(
              Map<String, dynamic>.from(s as Map),
            ),
          )
          .toList();
      if (!mounted || ref.read(adminResearchActorReaderProvider)() != _owner) {
        return;
      }
      _reviewContext = context;
      _sectionDecisions.clear();
      _manualSectionEdits.clear();
      for (final value in context['decisions'] as List) {
        final choice = value as Map;
        final id = choice['section_id'] as String;
        _sectionDecisions[id] = choice['decision'] == 'reject'
            ? 'rejected'
            : 'accepted';
        if (choice['decision'] == 'edit') {
          _manualSectionEdits[id] = choice['edited_text'] as String;
        }
      }
      _reviewerNotesController.text = context['note'] as String? ?? '';
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
          _error = e is CmsException
              ? e.toString()
              : const CmsException('unavailable').toString();
        });
      }
    }
  }

  void _handleSectionAction(String sectionId, String action) {
    setState(() {
      _sectionDecisions[sectionId] = action == 'accept'
          ? 'accepted'
          : 'rejected';
      if (action == 'reject') _manualSectionEdits.remove(sectionId);
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
    if (prop == null || _isSubmitting || _reviewContext?['stale'] == true) {
      return;
    }

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

    if (confirmed != true ||
        !mounted ||
        _reviewContext == null ||
        ref.read(adminResearchActorReaderProvider)() != _owner) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await ref
          .read(researchReviewRepositoryProvider)
          .save(
            context: _reviewContext!,
            mode: decision == SourceProposalReviewStatus.approved
                ? 'create_draft'
                : 'reject_proposal',
            decisions: _sectionDecisions,
            edits: _manualSectionEdits,
            note: _reviewerNotesController.text.trim(),
          );
      final ok =
          result['published'] == false &&
          (decision != SourceProposalReviewStatus.approved ||
              (result['draft_revision'] is Map &&
                  result['draft_revision']['editorial_state'] == 'draft'));
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is CmsException
                  ? e.toString()
                  : const CmsException('unavailable').toString(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _saveReview() async {
    if (_reviewContext == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(researchReviewRepositoryProvider)
          .save(
            context: _reviewContext!,
            mode: 'save_review',
            decisions: _sectionDecisions,
            edits: _manualSectionEdits,
            note: _reviewerNotesController.text.trim(),
          );
      if (!mounted) return;
      setState(() => _isDirty = false);
      await _loadData();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Review was not saved. Refresh if the version changed.',
            ),
          ),
        );
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
    ref.listen(supabaseAuthUserIdProvider, (_, next) {
      if (next.valueOrNull != _owner && mounted) {
        setState(() {
          _proposal = null;
          _reviewContext = null;
          _baseSections = [];
          _sectionDecisions.clear();
          _manualSectionEdits.clear();
          _reviewerNotesController.clear();
          _isDirty = false;
        });
      }
    });
    if (ref.watch(supabaseAuthUserIdProvider).valueOrNull != _owner ||
        _owner == null) {
      return const Scaffold(
        body: Center(child: Text('Administrator session required.')),
      );
    }
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
                  if (_reviewContext?['structured_patches'] == null &&
                      (_reviewContext?['base'] as Map?)?['rich_sections']
                          is List)
                    ExpansionTile(
                      title: Text(
                        isFa
                            ? 'ساختار کامل نسخه اصلی'
                            : 'Complete original structure',
                      ),
                      subtitle: Text(
                        isFa
                            ? 'تصمیم‌ها قابل ذخیره‌اند. تغییر متن واردشده تا تطبیق ساختار اصلی مسدود است.'
                            : 'Review decisions can be saved. Imported body changes require rich-structure reconciliation.',
                      ),
                      children: [
                        for (final section
                            in (_reviewContext!['base'] as Map)['rich_sections']
                                as List) ...[
                          Text((section as Map)['heading'] as String? ?? ''),
                          for (final block in section['blocks'] as List)
                            EditorialRichBlock(
                              block: Map<String, dynamic>.from(block as Map),
                            ),
                        ],
                      ],
                    ),
                  // Full-Page Comparison Viewer Component
                  if (_reviewContext?['structured_patches'] is List)
                    StructuredReviewViewer(
                      sections:
                          (_reviewContext!['base'] as Map)['rich_sections']
                              as List,
                      patches: _reviewContext!['structured_patches'] as List,
                      decisions: _sectionDecisions,
                      edits: _manualSectionEdits,
                      onAction: _handleSectionAction,
                      onEdit: _handleSectionEdit,
                      isPersian: isFa,
                    )
                  else
                    FullPageComparisonViewer(
                      articleTitle:
                          (_reviewContext!['base'] as Map)['title'] as String,
                      countryFlag: _flagForCountry(_proposal!.countryCode),
                      countryName: _nameForCountry(
                        _proposal!.countryCode,
                        isFa,
                      ),
                      category: _proposal!.pathwaySlug,
                      baseRevision: _proposal!.baseRevision,
                      proposedRevision: _proposal!.baseRevision + 1,
                      lastVerifiedAt: null,
                      hasConflicts:
                          _reviewContext?['stale'] == true ||
                          _proposal!.factualStatus == FactualStatus.conflicting,
                      baseSections: _baseSections,
                      changes: _proposal!.changes,
                      evidence: _proposal!.evidence,
                      reviewerNotes: _proposal!.reviewerNotes,
                      sectionReviewDecisions: _sectionDecisions,
                      sectionEdits: _manualSectionEdits,
                      onSectionAction: _handleSectionAction,
                      onSectionEdit: _handleSectionEdit,
                      isPersian: isFa,
                    ),

                  // Only server-supplied related-article metadata is displayed.
                  // Never infer impacted titles from the research proposal.
                  _buildRelatedArticlesImpact(isFa),
                  const SizedBox(height: 24),

                  // Editorial Reviewer Controls & Human Authorization
                  if (_reviewContext?['stale'] == true)
                    Text(
                      isFa
                          ? 'نسخه مبنا تغییر کرده است؛ ذخیره مسدود است.'
                          : 'The baseline has changed. Reload before saving.',
                    ),
                  TextButton.icon(
                    onPressed: _isSubmitting || _reviewContext?['stale'] == true
                        ? null
                        : _saveReview,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      isFa ? 'ذخیره پیش‌نویس بازبینی' : 'Save review draft',
                    ),
                  ),
                  _buildReviewerControls(isFa),
                ],
              ),
      ),
    );
  }

  /// Displays only related articles explicitly returned in the authenticated
  /// review context. No mock lookup or inferred impact is used in production.
  Widget _buildRelatedArticlesImpact(bool isFa) {
    final base = _reviewContext?['base'];
    final raw = base is Map ? base['related_articles'] : null;
    if (raw is! List) return const SizedBox.shrink();
    final entries = <Map<String, String>>[];
    for (final value in raw) {
      if (value is! Map ||
          value['article_id'] is! String ||
          value['title'] is! String) {
        continue;
      }
      final title = (value['title'] as String).trim();
      if (title.isEmpty) continue;
      entries.add({
        'title': title,
        'reason': value['impact_reason'] is String
            ? (value['impact_reason'] as String).trim()
            : '',
      });
    }
    if (entries.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFa
                ? 'مقالات مرتبط متأثر از تغییرات این منبع:'
                : 'Affected Related Articles:',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry['title']!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  if (entry['reason']!.isNotEmpty)
                    Text(
                      entry['reason']!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
        ],
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

          // Reviewer Notes
          TextField(
            controller: _reviewerNotesController,
            onChanged: (_) => setState(() => _isDirty = true),
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
