import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/app_back_button.dart';
import '../../domain/document_draft_generator.dart';

enum _DraftKind { cv, sop }

/// Private, on-device, user-editable draft assembly. Nothing is uploaded,
/// stored remotely, evaluated as legal advice, or automatically published.
class DocumentDraftPage extends StatefulWidget {
  const DocumentDraftPage({super.key});

  @override
  State<DocumentDraftPage> createState() => _DocumentDraftPageState();
}

class _DocumentDraftPageState extends State<DocumentDraftPage> {
  final Map<String, TextEditingController> _fields = {
    for (final key in [
      'name',
      'email',
      'phone',
      'summary',
      'education',
      'experience',
      'skills',
      'projects',
      'languages',
      'program',
      'institution',
      'motivation',
      'preparation',
      'fit',
      'goals',
    ])
      key: TextEditingController(),
  };
  final TextEditingController _draft = TextEditingController();
  _DraftKind _kind = _DraftKind.cv;
  String? _error;

  bool get _fa => Localizations.localeOf(context).languageCode == 'fa';
  String _t(String en, String fa) => _fa ? fa : en;
  String _input(String key) => _fields[key]!.text;

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _draft.dispose();
    super.dispose();
  }

  void _generate() {
    try {
      final language = _fa ? DraftLanguage.fa : DraftLanguage.en;
      final text = _kind == _DraftKind.cv
          ? DocumentDraftGenerator.cv(
              language: language,
              fullName: _input('name'),
              email: _input('email'),
              phone: _input('phone'),
              summary: _input('summary'),
              education: _input('education'),
              experience: _input('experience'),
              skills: _input('skills'),
              projects: _input('projects'),
              languages: _input('languages'),
            )
          : DocumentDraftGenerator.statementOfPurpose(
              language: language,
              fullName: _input('name'),
              targetProgram: _input('program'),
              institution: _input('institution'),
              motivation: _input('motivation'),
              preparation: _input('preparation'),
              programFit: _input('fit'),
              goals: _input('goals'),
            );
      setState(() {
        _error = null;
        _draft.text = text;
      });
    } on DraftValidationException catch (error) {
      setState(() {
        _error = switch (error.reason) {
          'invalid_email' => _t(
            'Enter a valid email address.',
            'نشانی ایمیل معتبری وارد کنید.',
          ),
          'missing_cv_content' => _t(
            'Add at least one real CV section.',
            'دست‌کم یک بخش واقعی برای رزومه وارد کنید.',
          ),
          'input_too_long' => _t(
            'One input is too long.',
            'یکی از ورودی‌ها بیش از حد طولانی است.',
          ),
          'invalid_single_line' || 'invalid_control_character' => _t(
            'Remove invalid characters.',
            'کاراکترهای نامعتبر را حذف کنید.',
          ),
          _ => _t(
            'Complete the required fields.',
            'فیلدهای ضروری را تکمیل کنید.',
          ),
        };
      });
    }
  }

  Future<void> _copy() async {
    if (_draft.text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _draft.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('Draft copied.', 'متن پیش‌نویس کپی شد.'))),
    );
  }

  Future<void> _saveTxt() async {
    if (_draft.text.trim().isEmpty) return;
    try {
      final location = await FilePicker.saveFile(
        dialogTitle: _t('Save plain text draft', 'ذخیره پیش‌نویس متنی'),
        fileName: _kind == _DraftKind.cv ? 'RAD-CV.txt' : 'RAD-SOP.txt',
        type: FileType.custom,
        allowedExtensions: const ['txt'],
        bytes: Uint8List.fromList(utf8.encode(_draft.text)),
      );
      if (!mounted || location == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Draft saved.', 'پیش‌نویس ذخیره شد.'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Could not save. Try copying the text.',
              'ذخیره انجام نشد؛ متن را کپی کنید.',
            ),
          ),
        ),
      );
    }
  }

  Widget _field(
    String id,
    String english,
    String persian, {
    bool required = false,
    int lines = 1,
    TextDirection? direction,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: ValueKey('draft_input_$id'),
        controller: _fields[id],
        textDirection: direction,
        maxLength: 4000,
        maxLines: lines,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: '${_t(english, persian)}${required ? ' *' : ''}',
          border: const OutlineInputBorder(),
          alignLabelWithHint: lines > 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _t('CV & Statement of Purpose', 'رزومه و انگیزه‌نامه');
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/documents'),
        title: Text(title),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                _t(
                  'An editable outline based only on what you enter. '
                      'Nothing is sent to a server or saved automatically. '
                      'Review every statement and verify requirements with official sources.',
                  'پیش‌نویس قابل‌ویرایش فقط از اطلاعات واردشده شما ساخته می‌شود. '
                      'هیچ اطلاعاتی به سرور ارسال یا خودکار ذخیره نمی‌شود. '
                      'تمام ادعاها و الزامات را با منابع رسمی بررسی کنید.',
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<_DraftKind>(
                key: const ValueKey('draft_type'),
                initialValue: _kind,
                decoration: InputDecoration(
                  labelText: _t('Document type', 'نوع سند'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: _DraftKind.cv,
                    child: Text(_t('CV', 'رزومه')),
                  ),
                  DropdownMenuItem(
                    value: _DraftKind.sop,
                    child: Text(_t('Statement of Purpose', 'انگیزه‌نامه')),
                  ),
                ],
                onChanged: (kind) {
                  if (kind == null) return;
                  setState(() {
                    _kind = kind;
                    _error = null;
                    _draft.clear();
                  });
                },
              ),
              const SizedBox(height: 16),
              _field('name', 'Full name', 'نام و نام خانوادگی', required: true),
              if (_kind == _DraftKind.cv) ...[
                _field('email', 'Email', 'ایمیل', direction: TextDirection.ltr),
                _field('phone', 'Phone', 'تلفن', direction: TextDirection.ltr),
                _field('summary', 'Profile summary', 'خلاصه فردی', lines: 3),
                _field('education', 'Education', 'تحصیلات', lines: 3),
                _field('experience', 'Experience', 'سوابق حرفه‌ای', lines: 3),
                _field('skills', 'Skills', 'مهارت‌ها', lines: 2),
                _field('projects', 'Projects', 'پروژه‌ها', lines: 3),
                _field('languages', 'Languages', 'زبان‌ها', lines: 2),
              ] else ...[
                _field(
                  'program',
                  'Target program',
                  'رشته موردنظر',
                  required: true,
                ),
                _field(
                  'institution',
                  'Institution (optional)',
                  'مؤسسه (اختیاری)',
                ),
                _field(
                  'motivation',
                  'Your motivation',
                  'انگیزه شما',
                  required: true,
                  lines: 4,
                ),
                _field(
                  'preparation',
                  'Your preparation',
                  'پیشینه شما',
                  required: true,
                  lines: 4,
                ),
                _field(
                  'fit',
                  'Program fit (optional)',
                  'تناسب با برنامه',
                  lines: 3,
                ),
                _field(
                  'goals',
                  'Your goals',
                  'اهداف شما',
                  required: true,
                  lines: 4,
                ),
              ],
              if (_error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                key: const ValueKey('draft_generate'),
                onPressed: _generate,
                icon: const Icon(Icons.edit_document),
                label: Text(
                  _t('Build editable draft', 'ساخت پیش‌نویس قابل‌ویرایش'),
                ),
              ),
              if (_draft.text.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text(
                  _t('Editable draft', 'پیش‌نویس قابل‌ویرایش'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('draft_output'),
                  controller: _draft,
                  minLines: 9,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey('draft_export_txt'),
                  onPressed: _saveTxt,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(_t('Save as TXT', 'ذخیره به‌صورت TXT')),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey('draft_copy'),
                  onPressed: _copy,
                  icon: const Icon(Icons.copy),
                  label: Text(_t('Copy edited text', 'کپی متن ویرایش‌شده')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
