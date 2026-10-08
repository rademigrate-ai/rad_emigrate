import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/network/api_exception.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _RecoveryRepository implements AuthRepository {
  final emails = <String>[];
  Completer<void>? pending;
  Object? error;

  @override
  Future<void> requestPasswordReset({required String email}) async {
    emails.add(email);
    final request = pending;
    if (request != null) await request.future;
    if (error case final failure?) throw failure;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _showRecovery(
  WidgetTester tester,
  _RecoveryRepository repository,
  Locale locale,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          (ref) => AuthController(repository),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ForgotPasswordPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in [const Locale('en'), const Locale('fa')]) {
    testWidgets(
      '${locale.languageCode}: failed recovery retains email and permits retry without false success',
      (tester) async {
        final repository = _RecoveryRepository()
          ..error = StateError('private backend failure detail');
        final l10n = lookupAppLocalizations(locale);
        await _showRecovery(tester, repository, locale);
        expect(find.text(l10n.passwordResetSubtitle), findsOneWidget);
        expect(find.text(l10n.signInSubtitle), findsNothing);

        await tester.enterText(
          find.byType(TextFormField),
          'recovery@example.test',
        );
        await tester.tap(find.text(l10n.sendResetLink));
        await tester.pumpAndSettle();

        expect(find.text(l10n.passwordResetSent), findsNothing);
        expect(find.text(l10n.passwordResetFailed), findsOneWidget);
        expect(find.text('private backend failure detail'), findsNothing);
        expect(find.text('recovery@example.test'), findsOneWidget);
        expect(find.text(l10n.sendResetLink), findsOneWidget);

        repository.error = null;
        await tester.tap(find.text(l10n.sendResetLink));
        await tester.pumpAndSettle();

        expect(repository.emails, [
          'recovery@example.test',
          'recovery@example.test',
        ]);
        expect(find.text(l10n.passwordResetSent), findsOneWidget);
        expect(find.text(l10n.passwordResetFailed), findsNothing);
        expect(find.byType(TextFormField), findsNothing);
      },
    );
  }

  testWidgets('pending recovery blocks duplicate sends and shows no success', (
    tester,
  ) async {
    final repository = _RecoveryRepository()..pending = Completer<void>();
    final l10n = lookupAppLocalizations(const Locale('en'));
    await _showRecovery(tester, repository, const Locale('en'));
    await tester.enterText(find.byType(TextFormField), 'recovery@example.test');
    await tester.tap(find.text(l10n.sendResetLink));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(repository.emails, ['recovery@example.test']);
    expect(find.text(l10n.passwordResetSent), findsNothing);
    repository.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text(l10n.passwordResetSent), findsOneWidget);
  });

  testWidgets('rate-limited recovery shows retry guidance and blocks resends', (
    tester,
  ) async {
    final repository = _RecoveryRepository()
      ..error = const ApiException(
        message: 'Email rate limit exceeded',
        statusCode: 429,
        code: 'over_email_send_rate_limit',
      );
    final l10n = lookupAppLocalizations(const Locale('en'));
    await _showRecovery(tester, repository, const Locale('en'));
    await tester.enterText(find.byType(TextFormField), 'recovery@example.test');

    await tester.tap(find.text(l10n.sendResetLink));
    await tester.pump();

    expect(find.text(l10n.passwordResetRateLimited), findsOneWidget);
    expect(repository.emails, ['recovery@example.test']);

    await tester.tap(find.text(l10n.sendResetLink));
    await tester.pump();
    expect(repository.emails, ['recovery@example.test']);
  });
}
