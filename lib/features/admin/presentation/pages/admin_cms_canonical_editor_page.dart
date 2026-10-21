import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/rad_contract.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/admin_cms_repository.dart';

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
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/admin/cms'),
        title: const Text('ویرایش پیش‌نویس مقاله'),
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
                  Text(
                    'شناسه: ${_draft!.id} • ${_draft!.locale} • نسخه ${_draft!.revision}',
                  ),
                  const Text(
                    'ذخیره، بررسی انسانی و انتشار عملیات جداگانه هستند. وضعیت تأیید رسمی در این فرم تغییر نمی‌کند.',
                  ),
                  TextField(
                    key: const Key('cms-title'),
                    controller: _title,
                    enabled: !_saving,
                    onChanged: (_) => _requestKey = null,
                    maxLength: 300,
                    decoration: const InputDecoration(labelText: 'عنوان'),
                  ),
                  TextField(
                    key: const Key('cms-summary'),
                    controller: _summary,
                    enabled: !_saving,
                    onChanged: (_) => _requestKey = null,
                    maxLength: 1500,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'خلاصه'),
                  ),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'در حال ذخیره…' : 'ذخیره پیش‌نویس'),
                  ),
                ],
              ],
            ),
    );
  }
}
