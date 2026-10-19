import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/documents/presentation/pages/document_draft_page.dart';

void main() {
  testWidgets('SOP mode validates mandatory fields and stays editable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: DocumentDraftPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('draft_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statement of Purpose').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('draft_input_program')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('draft_generate')));
    await tester.pump();
    expect(find.text('Complete the required fields.'), findsOneWidget);

    const fields = {
      'name': 'Applicant Provided',
      'program': 'Chosen Program',
      'motivation': 'My authored motivation',
      'preparation': 'My authored preparation',
      'goals': 'My authored goals',
    };
    for (final field in fields.entries) {
      final locator = find.byKey(ValueKey('draft_input_${field.key}'));
      await tester.ensureVisible(locator);
      await tester.enterText(locator, field.value);
    }
    await tester.ensureVisible(find.byKey(const ValueKey('draft_generate')));
    await tester.tap(find.byKey(const ValueKey('draft_generate')));
    await tester.pumpAndSettle();

    final output = tester.widget<TextField>(
      find.byKey(const ValueKey('draft_output')),
    );
    expect(output.controller!.text, contains('Statement of Purpose'));
    for (final value in fields.values) {
      expect(output.controller!.text, contains(value));
    }
    expect(output.controller!.text, isNot(contains('Institution:')));
    expect(output.controller!.text, isNot(contains('guaranteed')));
  });
}
