/// Offline-first, deterministic document draft assembly from user-supplied facts.
/// No AI calls, persistence, legal claims, credential access, or publishing.
enum DraftLanguage { en, fa }

class DraftValidationException implements Exception {
  const DraftValidationException(this.reason);
  final String reason;

  @override
  String toString() => reason;
}

/// A user-editable plain text draft, not a verified immigration document.
abstract final class DocumentDraftGenerator {
  static String cv({
    required DraftLanguage language,
    required String fullName,
    String email = '',
    String phone = '',
    String summary = '',
    String education = '',
    String experience = '',
    String skills = '',
    String projects = '',
    String languages = '',
  }) {
    final name = _value(fullName, required: true);
    final mail = _value(email, singleLine: true);
    final number = _value(phone, singleLine: true);
    if (mail.isNotEmpty &&
        (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(mail) ||
            mail.length > 254)) {
      throw const DraftValidationException('invalid_email');
    }
    final details = [
      _section(language, 'Profile', 'خلاصه فردی', summary),
      _section(language, 'Education', 'تحصیلات', education),
      _section(language, 'Experience', 'سوابق حرفه‌ای', experience),
      _section(language, 'Skills', 'مهارت‌ها', skills),
      _section(language, 'Projects', 'پروژه‌ها', projects),
      _section(language, 'Languages', 'زبان‌ها', languages),
    ].where((item) => item.isNotEmpty).toList();
    if (details.isEmpty) {
      throw const DraftValidationException('missing_cv_content');
    }
    return [
      _heading(language, 'Curriculum Vitae', 'رزومه'),
      name,
      if (mail.isNotEmpty) mail,
      if (number.isNotEmpty) number,
      '',
      ..._joinedSections(details),
    ].join('\n').trim();
  }

  static String statementOfPurpose({
    required DraftLanguage language,
    required String fullName,
    required String targetProgram,
    required String motivation,
    required String preparation,
    required String goals,
    String institution = '',
    String programFit = '',
  }) {
    final name = _value(fullName, required: true);
    final program = _value(targetProgram, required: true);
    final motivationText = _value(motivation, required: true);
    final preparationText = _value(preparation, required: true);
    final goalsText = _value(goals, required: true);
    final university = _value(institution, singleLine: true);
    final fit = _value(programFit);
    return [
      _heading(language, 'Statement of Purpose', 'انگیزه‌نامه'),
      '${_heading(language, 'Applicant', 'متقاضی')}: $name',
      '${_heading(language, 'Intended Program', 'رشته یا برنامه موردنظر')}: $program',
      if (university.isNotEmpty)
        '${_heading(language, 'Institution', 'مؤسسه موردنظر')}: $university',
      '',
      _section(language, 'Motivation', 'انگیزه', motivationText),
      '',
      _section(
        language,
        'Academic and Professional Preparation',
        'آمادگی تحصیلی و حرفه‌ای',
        preparationText,
      ),
      if (fit.isNotEmpty) ...[
        '',
        _section(language, 'Program Fit', 'تناسب با برنامه', fit),
      ],
      '',
      _section(language, 'Goals', 'اهداف', goalsText),
    ].join('\n').trim();
  }

  static String _heading(DraftLanguage lang, String english, String persian) =>
      lang == DraftLanguage.fa ? persian : english;

  static String _section(
    DraftLanguage lang,
    String english,
    String persian,
    String value,
  ) {
    final text = _value(value);
    return text.isEmpty ? '' : '${_heading(lang, english, persian)}\n$text';
  }

  static Iterable<String> _joinedSections(List<String> sections) sync* {
    for (var i = 0; i < sections.length; i++) {
      if (i != 0) yield '';
      yield sections[i];
    }
  }

  static String _value(
    String value, {
    bool required = false,
    bool singleLine = false,
  }) {
    if (value.length > 12000) {
      throw const DraftValidationException('input_too_long');
    }
    if (RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]').hasMatch(value)) {
      throw const DraftValidationException('invalid_control_character');
    }
    final clean = value.replaceAll('\r\n', '\n').trim();
    if (singleLine && clean.contains('\n')) {
      throw const DraftValidationException('invalid_single_line');
    }
    if (required && clean.isEmpty) {
      throw const DraftValidationException('required');
    }
    return clean;
  }
}
