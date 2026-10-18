import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/documents/domain/document_draft_generator.dart';

void main() {
  group('Offline deterministic CV drafts', () {
    test('uses only authored fields without invented qualifications', () {
      final draft = DocumentDraftGenerator.cv(
        language: DraftLanguage.en,
        fullName: 'Casey Test',
        email: 'casey@example.invalid',
        skills: 'User supplied skill',
        education: 'User supplied degree',
      );
      expect(draft, contains('Curriculum Vitae'));
      expect(draft, contains('Casey Test'));
      expect(draft, contains('casey@example.invalid'));
      expect(draft, contains('User supplied skill'));
      expect(draft, contains('User supplied degree'));
      expect(draft, isNot(contains('University of')));
      expect(draft, isNot(contains('years of experience')));
      expect(draft, isNot(contains('visa')));
      expect(draft, isNot(contains('null')));
    });

    test('Persian headings and Unicode remain intact', () {
      final draft = DocumentDraftGenerator.cv(
        language: DraftLanguage.fa,
        fullName: 'آزمایش کاربر',
        experience: 'سابقه واقعی ارائه‌شده',
      );
      expect(draft, contains('رزومه'));
      expect(draft, contains('سوابق حرفه‌ای'));
      expect(draft, contains('آزمایش کاربر'));
      expect(draft, isNot(contains('Education')));
    });

    test('refuses empty sections or missing name', () {
      expect(
        () => DocumentDraftGenerator.cv(
          language: DraftLanguage.en,
          fullName: 'Test',
        ),
        throwsA(isA<DraftValidationException>()),
      );
      expect(
        () => DocumentDraftGenerator.cv(
          language: DraftLanguage.en,
          fullName: ' ',
          skills: 'Dart',
        ),
        throwsA(isA<DraftValidationException>()),
      );
    });

    test('rejects invalid email and header injection', () {
      for (final address in [
        'invalid',
        'a@b.example\nBcc: victim@example.com',
      ]) {
        expect(
          () => DocumentDraftGenerator.cv(
            language: DraftLanguage.en,
            fullName: 'Test',
            email: address,
            skills: 'Dart',
          ),
          throwsA(isA<DraftValidationException>()),
        );
      }
    });
  });

  group('Statement of purpose', () {
    test('never invents an institution or extra claims', () {
      final result = DocumentDraftGenerator.statementOfPurpose(
        language: DraftLanguage.en,
        fullName: 'Taylor Test',
        targetProgram: 'User chosen subject',
        motivation: 'I have written my motivation.',
        preparation: 'I have written my preparation.',
        goals: 'I have written my goals.',
      );
      expect(result, contains('Statement of Purpose'));
      expect(result, contains('User chosen subject'));
      expect(result, contains('I have written my preparation.'));
      expect(result, isNot(contains('Institution:')));
      expect(result, isNot(contains('scholarship')));
      expect(result, isNot(contains('acceptance')));
    });

    test('all mandatory user-provided sections are required', () {
      expect(
        () => DocumentDraftGenerator.statementOfPurpose(
          language: DraftLanguage.fa,
          fullName: 'کاربر',
          targetProgram: 'برنامه',
          motivation: 'هدف',
          preparation: ' ',
          goals: 'آینده',
        ),
        throwsA(isA<DraftValidationException>()),
      );
    });

    test('refuses control chars and overly large inputs', () {
      expect(
        () => DocumentDraftGenerator.statementOfPurpose(
          language: DraftLanguage.en,
          fullName: 'Bad\u0000',
          targetProgram: 'Program',
          motivation: 'A',
          preparation: 'B',
          goals: 'C',
        ),
        throwsA(isA<DraftValidationException>()),
      );
      expect(
        () => DocumentDraftGenerator.cv(
          language: DraftLanguage.en,
          fullName: 'Test',
          summary: 'x' * 12001,
        ),
        throwsA(isA<DraftValidationException>()),
      );
    });
  });
}
