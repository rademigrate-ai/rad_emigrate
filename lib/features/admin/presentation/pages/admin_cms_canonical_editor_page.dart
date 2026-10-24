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
  CmsArticleDraft? _draft;
  AdminCmsRepository? _repository;
  String? _error;
  String? _requestKey;
  bool _loading = true;
  bool _saving = false;
  int _generation = 0;

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

  Future<void> _submitReview() async {
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
        contentHash: '0' * 64, // placeholder hash if not calculated
        note: 'ارسال برای بررسی سردبیری از پنل مدیریت',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authenticatedUserIdProvider, (previous, next) {
      if (previous == next) return;
      _title.clear();
      _summary.clear();
      _requestKey = null;
      _saving = false;
      _load();
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/admin/cms'),
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
                if (_error != null) Text(_error!, key: const Key('cms-error')),
                if (_draft == null)
                  TextButton(onPressed: _load, child: const Text('تلاش مجدد')),
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
                          'ذخیره، بررسی انسانی و انتشار عملیات جداگانه هستند. وضعیت تأیید رسمی در این فرم تغییر نمی‌کند.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

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
                          onChanged: (_) => _requestKey = null,
                          maxLength: 300,
                          decoration: const InputDecoration(labelText: 'عنوان'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('cms-summary'),
                          controller: _summary,
                          enabled: !_saving,
                          onChanged: (_) => _requestKey = null,
                          maxLength: 1500,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: 'خلاصه'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(
                            _saving ? 'در حال ذخیره…' : 'ذخیره پیش‌نویس',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _saving ? null : _submitReview,
                        child: const Text('ارسال به بررسی'),
                      ),
                    ],
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
    );
  }
}
