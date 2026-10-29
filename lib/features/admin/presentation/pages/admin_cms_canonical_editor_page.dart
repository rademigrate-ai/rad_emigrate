import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/supabase/rad_contract.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/admin_cms_repository.dart';
import '../../domain/entities/admin_cms_entities.dart';

class AdminCmsCanonicalEditorPage extends ConsumerStatefulWidget {
  const AdminCmsCanonicalEditorPage({
    super.key,
    required this.articleId,
    this.locale = 'fa',
  });
  final String articleId;
  final String locale;
  @override
  ConsumerState<AdminCmsCanonicalEditorPage> createState() => _EditorState();
}

class _EditorState extends ConsumerState<AdminCmsCanonicalEditorPage> {
  final _title = TextEditingController();
  final _summary = TextEditingController();
  String _initialTitle = '';
  String _initialSummary = '';
  CmsArticleDraft? _draft;
  AdminCmsRepository? _repository;
  String? _error;
  String? _requestKey;
  bool _loading = true;
  bool _saving = false;
  int _generation = 0;

  bool get _isDirty =>
      _draft != null &&
      (_title.text.trim() != _initialTitle.trim() ||
          _summary.text.trim() != _initialSummary.trim());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminCmsCanonicalEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articleId != widget.articleId ||
        oldWidget.locale != widget.locale) {
      _title.clear();
      _summary.clear();
      _initialTitle = '';
      _initialSummary = '';
      _requestKey = null;
      _load();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final repository = ref.read(adminCmsRepositoryProvider);
    setState(() {
      _loading = true;
      _saving = false;
      _error = null;
      _draft = null;
    });
    try {
      final draft = await repository.getArticleDraft(
        widget.articleId,
        locale: widget.locale,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _repository = repository;
        _draft = draft;
        _title.text = draft.title;
        _summary.text = draft.summary;
        _initialTitle = draft.title;
        _initialSummary = draft.summary;
        _loading = false;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _discardEdits() {
    setState(() {
      _title.text = _initialTitle;
      _summary.text = _initialSummary;
      _requestKey = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تغییرات ویرایشگر بازنشانی شد.')),
    );
  }

  Future<bool> _confirmDiscardUnsaved() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        key: const Key('cms-discard-dialog'),
        title: const Text('تغییرات ذخیره‌نشده'),
        content: const Text(
          'تغییراتی در عنوان یا خلاصه مقاله اعمال کرده‌اید که هنوز ذخیره نشده است. با خروج از این صفحه، تغییرات ذخیره‌نشده از دست خواهند رفت.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            key: const Key('cms-discard-cancel'),
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('ادامه ویرایش'),
          ),
          FilledButton(
            key: const Key('cms-discard-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('نادیده گرفتن و خروج'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _validateHash(String hash) {
    final trimmed = hash.trim();
    if (trimmed.isEmpty ||
        trimmed == ('0' * 64) ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(trimmed)) {
      throw const CmsException('malformed');
    }
    return trimmed;
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _title.text.trim().isEmpty || _saving) return;
    final generation = _generation;
    // Reuse the same idempotency key on uncertain retries; edits create a new key.
    _requestKey ??= newRadRequestKey();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ok = await _repository!.saveCanonicalArticle(
        draft,
        title: _title.text.trim(),
        summary: _summary.text.trim(),
        requestKey: _requestKey!,
      );
      if (!mounted || generation != _generation) return;
      if (!ok) throw const CmsException('malformed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پیش‌نویس ذخیره شد؛ منتشر نشده است.')),
      );
      _requestKey = null;
      await _load();
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  Future<void> _handleSubmitReviewPrompt() async {
    final draft = _draft;
    if (draft == null || _saving) return;

    if (_isDirty) {
      final shouldSaveFirst = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          key: const Key('cms-submit-dirty-dialog'),
          title: const Text('تغییرات ذخیره‌نشده وجود دارد'),
          content: const Text(
            'برای ارسال تغییرات فعلی به بررسی سردبیری، ابتدا باید پیش‌نویس جدید ذخیره شود تا شناسه و هش سرور تولید گردد. آیا می‌خواهید ابتدا تغییرات ذخیره شوند؟',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, null),
              child: const Text('انصراف'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('ارسال نسخه قبلی بدون ذخیره'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('ذخیره و ارسال'),
            ),
          ],
        ),
      );
      if (shouldSaveFirst == null) return;
      if (shouldSaveFirst == true) {
        await _save();
        if (_error != null || !mounted) return;
      }
    }

    _showSubmitReviewDialog();
  }

  Future<void> _showSubmitReviewDialog() async {
    final draft = _draft;
    if (draft == null || _saving) return;
    final note = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => _CmsSubmitReviewDialog(revision: draft.revision),
    );
    if (note != null && mounted) {
      await _executeSubmitReview(
        note.isEmpty ? 'ارسال برای بررسی سردبیری از پنل مدیریت' : note,
      );
    }
  }

  Future<void> _executeSubmitReview(String note) async {
    final draft = _draft;
    if (draft == null || _saving) return;
    final generation = _generation;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository!.submitArticleReview(
        articleId: draft.id,
        revisionId: draft.revisionId,
        expectedRevision: draft.revision,
        contentHash: _validateHash(draft.contentHash),
        note: note,
        requestKey: newRadRequestKey(),
      );
      if (!mounted || generation != _generation) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نسخه برای بررسی سردبیری ارسال شد.')),
      );
      await _load();
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  Future<void> _showApproveDialog() async {
    final draft = _draft;
    if (draft == null || _saving) return;
    final note = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => _CmsApproveDialog(revision: draft.revision),
    );
    if (note != null && mounted) {
      await _executeApprove(
        note.isEmpty ? 'تأیید رسمی نسخه توسط مدیر ارشد محتوا' : note,
      );
    }
  }

  Future<void> _executeApprove(String note) async {
    final draft = _draft;
    if (draft == null || _saving) return;
    final generation = _generation;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository!.approveArticleRevision(
        articleId: draft.id,
        revisionId: draft.revisionId,
        expectedRevision: draft.revision,
        contentHash: _validateHash(draft.contentHash),
        note: note,
        requestKey: newRadRequestKey(),
      );
      if (!mounted || generation != _generation) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نسخه با موفقیت توسط سردبیر تأیید شد.')),
      );
      await _load();
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  Future<void> _showRejectDialog() async {
    final draft = _draft;
    if (draft == null || _saving) return;
    final note = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => _CmsRejectDialog(revision: draft.revision),
    );
    if (note != null && mounted) {
      await _executeReject(note);
    }
  }

  Future<void> _executeReject(String note) async {
    final draft = _draft;
    if (draft == null || _saving) return;
    final generation = _generation;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository!.rejectArticleRevision(
        articleId: draft.id,
        revisionId: draft.revisionId,
        expectedRevision: draft.revision,
        contentHash: _validateHash(draft.contentHash),
        note: note,
        requestKey: newRadRequestKey(),
      );
      if (!mounted || generation != _generation) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('نسخه رد شد.')));
      await _load();
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  void _showPublishDialog() {
    final draft = _draft;
    if (draft == null || _saving) return;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        key: const Key('cms-publish-dialog'),
        title: Row(
          children: [
            const Icon(Icons.public, color: AppColors.teal),
            const SizedBox(width: 8),
            Text('انتشار رسمی نسخه ${draft.revision}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Text(
                'توجه: انتشار مقاله مستلزم مجوز صریح انسانی است و بلافاصله نسخه تأییدشده را برای عموم کاربران فعال خواهد کرد.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'شناسه نسخه: ${draft.revisionId}',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
            Text(
              'هش محتوا: ${draft.contentHash.length >= 16 ? draft.contentHash.substring(0, 16) : draft.contentHash}...',
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            key: const Key('cms-publish-confirm-button'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _executePublish();
            },
            child: const Text('تأیید و انتشار عمومی'),
          ),
        ],
      ),
    );
  }

  Future<void> _executePublish() async {
    final draft = _draft;
    if (draft == null || _saving) return;
    final generation = _generation;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository!.publishArticleRevision(
        articleId: draft.id,
        revisionId: draft.revisionId,
        contentHash: _validateHash(draft.contentHash),
        requestKey: newRadRequestKey(),
      );
      if (!mounted || generation != _generation) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مقاله با موفقیت به صورت رسمی منتشر شد.')),
      );
      await _load();
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  void _showRevisionsHistory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<List<RevisionSummary>>(
              future: _repository!.listArticleRevisions(
                articleId: widget.articleId,
                locale: widget.locale,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: RadPending());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('خطا در دریافت تاریخچه: ${snapshot.error}'),
                    ),
                  );
                }
                final revisions = snapshot.data ?? const [];
                if (revisions.isEmpty) {
                  return const Center(child: Text('هیچ نسخه‌ای ثبت نشده است.'));
                }

                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'تاریخچه نسخه‌ها و تغییرات',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: widget.locale == 'fa' ? 'بستن' : 'Close',
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const Divider(),
                    ...revisions.map((rev) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'نسخه ${rev.revision}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.teal.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.pill,
                                      ),
                                    ),
                                    child: Text(
                                      rev.editorialState.toDisplayPersian(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.teal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'شناسه: ${rev.revisionId}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Text(
                                'تاریخ ایجاد: ${rev.createdAt.toLocal().toString().split('.').first}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (rev.reason != null &&
                                  rev.reason!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'علت تغییر: ${rev.reason}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      side: const BorderSide(
                                        color: AppColors.warning,
                                      ),
                                    ),
                                    onPressed: () =>
                                        _confirmRollback(rev, sheetContext),
                                    child: const Text(
                                      'بازگردانی به این نسخه',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _confirmRollback(RevisionSummary rev, BuildContext sheetCtx) {
    final reasonController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text('بازگردانی مقاله به نسخه ${rev.revision}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'آیا از بازگردانی این مقاله اطمینان دارید؟ نسخه فعلی جایگزین خواهد شد.',
                style: TextStyle(fontSize: 13),
              ),
              if (_isDirty) ...[
                const SizedBox(height: 8),
                const Text(
                  'توجه: تغییرات ذخیره‌نشده در فرم فعلی با بازگردانی نسخه جایگزین خواهد شد.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'دلیل بازگردانی (الزامی)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('انصراف'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) return;
                Navigator.pop(dialogCtx);
                Navigator.pop(sheetCtx);
                setState(() => _saving = true);
                try {
                  await _repository!.rollbackArticle(
                    articleId: widget.articleId,
                    locale: widget.locale,
                    fromRevisionId: rev.revisionId,
                    expectedRevision: _draft?.revision ?? rev.revision,
                    reason: reason,
                    requestKey: newRadRequestKey(),
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('مقاله با موفقیت بازگردانی شد.'),
                    ),
                  );
                  await _load();
                } catch (e) {
                  if (mounted) {
                    setState(() => _error = e.toString());
                  }
                } finally {
                  if (mounted) setState(() => _saving = false);
                }
              },
              child: const Text('تأیید بازگردانی'),
            ),
          ],
        );
      },
    ).then((_) => reasonController.dispose());
  }

  Widget _buildEditorialActions() {
    final draft = _draft;
    if (draft == null) return const SizedBox.shrink();

    final state = draft.editorialState;
    final isDraft = state == ArticleEditorialStatus.draft;
    final isReview = state == ArticleEditorialStatus.inReview;
    final isApproved = state == ArticleEditorialStatus.approved;
    final isPublished = state == ArticleEditorialStatus.published;

    return Container(
      key: const Key('cms-lifecycle-panel'),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
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
              const Text(
                'چرخه سردبیری و انتشار',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isPublished
                      ? Colors.green.withValues(alpha: 0.12)
                      : isApproved
                      ? AppColors.teal.withValues(alpha: 0.12)
                      : isReview
                      ? AppColors.warning.withValues(alpha: 0.12)
                      : AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  state.toDisplayPersian(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPublished
                        ? Colors.green.shade800
                        : isApproved
                        ? AppColors.teal
                        : isReview
                        ? AppColors.warning
                        : AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: const Key('cms-save-button'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'در حال ذخیره…' : 'ذخیره پیش‌نویس'),
              ),
              OutlinedButton(
                key: const Key('cms-submit-review-button'),
                onPressed: _saving ? null : _handleSubmitReviewPrompt,
                child: const Text('ارسال به بررسی'),
              ),
              if (isReview || isDraft) ...[
                OutlinedButton(
                  key: const Key('cms-approve-button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    side: const BorderSide(color: AppColors.teal),
                  ),
                  onPressed: _saving ? null : _showApproveDialog,
                  child: const Text('تأیید سردبیری'),
                ),
                OutlinedButton(
                  key: const Key('cms-reject-button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.navy),
                  ),
                  onPressed: _saving ? null : _showRejectDialog,
                  child: const Text('رد نسخه'),
                ),
              ],
              if (isApproved || isReview) ...[
                FilledButton.icon(
                  key: const Key('cms-publish-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                  ),
                  onPressed: _saving ? null : _showPublishDialog,
                  icon: const Icon(Icons.public, size: 16),
                  label: const Text('انتشار رسمی'),
                ),
              ],
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
      _title.clear();
      _summary.clear();
      _initialTitle = '';
      _initialSummary = '';
      _requestKey = null;
      _saving = false;
      _load();
    });

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _isDirty) {
          final discard = await _confirmDiscardUnsaved();
          if (discard && context.mounted) {
            AppBackButton.goBack(context, fallback: '/admin/cms');
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: AppBackButton(
            fallback: '/admin/cms',
            onPressed: () async {
              if (_isDirty) {
                final discard = await _confirmDiscardUnsaved();
                if (discard && context.mounted) {
                  AppBackButton.goBack(context, fallback: '/admin/cms');
                }
              } else {
                AppBackButton.goBack(context, fallback: '/admin/cms');
              }
            },
          ),
          title: const Text('ویرایش پیش‌نویس مقاله'),
          actions: [
            if (_draft != null && _repository != null)
              IconButton(
                tooltip: 'تاریخچه نسخه‌ها و بازگردانی',
                icon: const Icon(Icons.history),
                onPressed: _showRevisionsHistory,
              ),
          ],
        ),
        body: _loading
            ? const Center(child: RadPending())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Text(_error!, key: const Key('cms-error')),
                  if (_draft == null)
                    TextButton(
                      onPressed: _load,
                      child: const Text('تلاش مجدد'),
                    ),
                  if (_draft != null) ...[
                    // Header badge
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'شناسه: ${_draft!.id} • ${_draft!.locale} • نسخه ${_draft!.revision}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'ذخیره، بررسی انسانی و انتشار عملیات جداگانه هستند. انتشار مستلزم تأیید صریح انسانی است.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Unsaved changes warning banner (F06)
                    if (_isDirty)
                      Container(
                        key: const Key('cms-unsaved-warning'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_note,
                              color: AppColors.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'تغییرات ذخیره‌نشده در ویرایشگر وجود دارد.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            TextButton(
                              key: const Key('cms-discard-button'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: _discardEdits,
                              child: const Text(
                                'بازنشانی تغییرات',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Lifecycle panel (F05)
                    _buildEditorialActions(),

                    // Title & Summary inputs
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            key: const Key('cms-title'),
                            controller: _title,
                            enabled: !_saving,
                            onChanged: (_) =>
                                setState(() => _requestKey = null),
                            maxLength: 300,
                            decoration: const InputDecoration(
                              labelText: 'عنوان',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            key: const Key('cms-summary'),
                            controller: _summary,
                            enabled: !_saving,
                            onChanged: (_) =>
                                setState(() => _requestKey = null),
                            maxLength: 1500,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'خلاصه',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section list inspection
                    if (_draft!.rawSections.isNotEmpty) ...[
                      const Text(
                        'بخش‌های ساختاریافته مقاله:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._draft!.rawSections.map((sec) {
                        final heading =
                            sec['heading']?.toString() ?? 'بدون عنوان';
                        final anchor = sec['anchor']?.toString() ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    heading,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (anchor.isNotEmpty)
                                    Text(
                                      '#$anchor',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                ],
                              ),
                              const Icon(
                                Icons.article,
                                size: 16,
                                color: AppColors.teal,
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

class _CmsSubmitReviewDialog extends StatefulWidget {
  final int revision;
  const _CmsSubmitReviewDialog({required this.revision});

  @override
  State<_CmsSubmitReviewDialog> createState() => _CmsSubmitReviewDialogState();
}

class _CmsSubmitReviewDialogState extends State<_CmsSubmitReviewDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: 'ارسال برای بررسی سردبیری از پنل مدیریت',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('cms-submit-review-dialog'),
      title: Text('ارسال نسخه ${widget.revision} برای بررسی سردبیری'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'با ارسال برای بررسی، نسخه به وضعیت «در حال بررسی» منتقل شده و جهت تأیید سردبیر آماده می‌شود.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'یادداشت بررسی (اختیاری)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('تأیید و ارسال'),
        ),
      ],
    );
  }
}

class _CmsApproveDialog extends StatefulWidget {
  final int revision;
  const _CmsApproveDialog({required this.revision});

  @override
  State<_CmsApproveDialog> createState() => _CmsApproveDialogState();
}

class _CmsApproveDialogState extends State<_CmsApproveDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: 'تأیید رسمی نسخه توسط مدیر ارشد محتوا',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('cms-approve-dialog'),
      title: Text('تأیید سردبیری نسخه ${widget.revision}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'با تأیید این نسخه، پیش‌نویس به وضعیت «تأیید سردبیری» ارتقا یافته و واجد شرایط انتشار رسمی خواهد بود.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'یادداشت تأیید (اختیاری)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('انصراف'),
        ),
        FilledButton(
          key: const Key('cms-approve-confirm-button'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('تأیید رسمی سردبیری'),
        ),
      ],
    );
  }
}

class _CmsRejectDialog extends StatefulWidget {
  final int revision;
  const _CmsRejectDialog({required this.revision});

  @override
  State<_CmsRejectDialog> createState() => _CmsRejectDialogState();
}

class _CmsRejectDialogState extends State<_CmsRejectDialog> {
  late final TextEditingController _controller;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final valid = _controller.text.trim().isNotEmpty;
    if (valid != _isValid) {
      setState(() => _isValid = valid);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('cms-reject-dialog'),
      title: Text('رد نسخه ${widget.revision}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'لطفاً دلیل رد نسخه را وارد نمایید. ثبت یادداشت رد برای حفظ سابقه الزامی است:',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('cms-reject-note-input'),
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'دلیل رد نسخه (الزامی)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('انصراف'),
        ),
        FilledButton(
          key: const Key('cms-reject-confirm-button'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
          onPressed: _isValid
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
          child: const Text('رد نسخه'),
        ),
      ],
    );
  }
}
