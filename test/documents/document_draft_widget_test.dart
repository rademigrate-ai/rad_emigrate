import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/documents/presentation/pages/document_draft_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  testWidgets('CV flow validates input then produces editable draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: DocumentDraftPage()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('draft_output')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('draft_generate')));
    await tester.pump();
    expect(find.text('Complete the required fields.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('draft_input_name')),
      'Test Applicant',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('draft_input_skills')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('draft_input_skills')),
      'User-authored only',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('draft_generate')));
    await tester.tap(find.byKey(const ValueKey('draft_generate')));
    await tester.pumpAndSettle();

    expect(find.text('Complete the required fields.'), findsNothing);
    final output = tester.widget<TextField>(
      find.byKey(const ValueKey('draft_output')),
    );
    expect(output.controller!.text, contains('Test Applicant'));
    expect(output.controller!.text, contains('User-authored only'));
    expect(output.controller!.text, isNot(contains('scholarship')));

    expect(find.byKey(const ValueKey('draft_export_txt')), findsOneWidget);
    // Draft stays editable; exporting or copying requires explicit action.
    await tester.enterText(
      find.byKey(const ValueKey('draft_output')),
      'Personally reviewed user text',
    );
    expect(output.controller!.text, 'Personally reviewed user text');
  });

  testWidgets('Persian generation has Persian headings and keeps user text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('fa'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: DocumentDraftPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('draft_input_name')),
      'متقاضی آزمایشی',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('draft_input_skills')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('draft_input_skills')),
      'مهارت نوشته‌شده توسط متقاضی',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('draft_generate')));
    await tester.tap(find.byKey(const ValueKey('draft_generate')));
    await tester.pumpAndSettle();

    final output = tester.widget<TextField>(
      find.byKey(const ValueKey('draft_output')),
    );
    expect(output.controller!.text, contains('رزومه'));
    expect(output.controller!.text, contains('مهارت نوشته‌شده توسط متقاضی'));
  });
}
