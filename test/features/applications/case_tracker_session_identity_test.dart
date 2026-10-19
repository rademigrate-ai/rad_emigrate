import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/features/applications/domain/entities/application_status.dart';
import 'package:rad_emigrate/features/applications/domain/entities/visa_application.dart';
import 'package:rad_emigrate/features/applications/presentation/providers/case_tracker_controller.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';

class _MockAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Provider-level regression tests for the identity the case tracker scopes
/// its persisted checklist to. Existing controller tests construct
/// [CaseTrackerController] with a hard-coded user id and therefore bypass the
/// provider's session -> application owner -> guest resolution chain.
void main() {
  const secretTitle = 'Confidential Client A Passport Copy';
  final clock = DateTime.utc(2026, 10, 19, 9);

  final appOwnedByA = VisaApplication(
    id: 'case-identity-001',
    userId: 'user-A',
    title: 'Study Permit',
    programName: 'Canada Study Permit',
    country: 'Canada',
    status: ApplicationStatus.submitted,
    updatedAt: clock,
    createdAt: clock.subtract(const Duration(days: 10)),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Persists a private checklist item for user A under A's scoped key.
  Future<SharedPreferences> seedUserAPrivateChecklist() async {
    final prefs = await SharedPreferences.getInstance();
    final seeding = CaseTrackerController(
      initialApp: appOwnedByA,
      userId: 'user-A',
      prefs: prefs,
    );
    await seeding.addChecklistItem(title: secretTitle);
    expect(
      seeding.state.checklist.items.any((i) => i.title == secretTitle),
      isTrue,
      reason: 'precondition: user A has a private persisted checklist item',
    );
    return prefs;
  }

  ProviderContainer containerFor(SharedPreferences prefs, UserSession session) {
    final auth = AuthController(_MockAuthRepo())..applySession(session);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authControllerProvider.overrideWith((ref) => auth),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  bool exposesSecret(ProviderContainer container) {
    final provider = caseTrackerControllerProvider(appOwnedByA);
    // Keep the autoDispose family alive while reading.
    container.listen(provider, (_, _) {});
    return container
        .read(provider)
        .checklist
        .items
        .any((i) => i.title == secretTitle);
  }

  group('case tracker identity resolution', () {
    test(
      'control: authenticated owner sees their own persisted checklist',
      () async {
        final prefs = await seedUserAPrivateChecklist();
        final container = containerFor(
          prefs,
          const UserSession(
            userId: 'user-A',
            token: 'token-A',
            authenticated: true,
          ),
        );
        expect(exposesSecret(container), isTrue);
      },
    );

    test('control: a different authenticated user does not see it', () async {
      final prefs = await seedUserAPrivateChecklist();
      final container = containerFor(
        prefs,
        const UserSession(
          userId: 'user-B',
          token: 'token-B',
          authenticated: true,
        ),
      );
      expect(exposesSecret(container), isFalse);
    });

    test(
      'logged-out session must not fall back to the application owner',
      () async {
        final prefs = await seedUserAPrivateChecklist();
        // Logout state: AuthController resets to an empty UserSession.
        final container = containerFor(prefs, const UserSession());
        expect(
          exposesSecret(container),
          isFalse,
          reason:
              'after logout the previous user\'s persisted checklist must '
              'not be readable just because the application carries their id',
        );
      },
    );

    test(
      'unauthenticated session with a stale userId is not trusted',
      () async {
        final prefs = await seedUserAPrivateChecklist();
        final container = containerFor(
          prefs,
          const UserSession(userId: 'user-A', authenticated: false),
        );
        expect(
          exposesSecret(container),
          isFalse,
          reason:
              'a session without a valid token is not authenticated and '
              'must not select user A\'s scoped storage',
        );
      },
    );
  });
}
