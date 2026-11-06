import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/documents/presentation/widgets/document_deletion_status.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  for (final locale in ['en', 'fa']) {
    for (final width in [390.0, 768.0, 1440.0]) {
      testWidgets('deletion states remain distinct in $locale at $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              documentDeletionStatusProvider.overrideWith(
                (ref) async => [
                  for (final state in [
                    'pending_storage',
                    'retrying',
                    'failed',
                    'finalized',
                  ])
                    DocumentDeletionStatus(id: state, state: state),
                ],
              ),
            ],
            child: MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: DocumentDeletionStatusPanel()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(
          find.byType(DocumentDeletionStatusPanel),
        );
        final l10n = AppLocalizations.of(context);
        for (final label in [
          l10n.documentDeletionPending,
          l10n.documentDeletionRetrying,
          l10n.documentDeletionFailed,
          l10n.documentDeletionComplete,
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(
          Directionality.of(context),
          locale == 'fa' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
