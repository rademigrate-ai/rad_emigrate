import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/status_badge.dart';
import 'package:rad_emigrate/features/applications/domain/entities/application_status.dart';
import 'package:rad_emigrate/features/applications/domain/entities/visa_application.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

/// Journey 7: Application creation model + status display.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('UJ07 application draft can transition to submitted via copyWith', () {
    final draft = VisaApplication(
      id: 'app-1',
      title: 'Study track',
      programName: 'Canada Study Permit',
      country: 'Canada',
      status: ApplicationStatus.draft,
      updatedAt: DateTime.utc(2026, 3, 1),
    );
    final submitted = draft.copyWith(
      status: ApplicationStatus.submitted,
      updatedAt: DateTime.utc(2026, 3, 2),
    );
    expect(submitted.status, ApplicationStatus.submitted);
    expect(submitted.status.label, 'Submitted');
    expect(submitted.id, 'app-1');
  });

  test('UJ07b status labels cover full lifecycle', () {
    for (final status in ApplicationStatus.values) {
      expect(status.label.trim(), isNotEmpty, reason: status.name);
    }
  });

  testWidgets('UJ07c StatusBadge announces status to semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: StatusBadge(label: 'Submitted', tone: StatusTone.info),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Submitted')), findsWidgets);
  });
}
