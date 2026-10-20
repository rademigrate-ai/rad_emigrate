// Widget tests for the Booking feature.
//
// The repository provider is overridden with a deterministic fake so no test
// ever depends on a live Backend — and no fake success is presented as a real
// Backend confirmation: the fake mirrors the contract (capability states,
// backend-unavailable exceptions) rather than inventing confirmations.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/core/widgets/app_button.dart';
import 'package:rad_emigrate/core/widgets/app_card.dart';
import 'package:rad_emigrate/core/widgets/app_text_field.dart';
import 'package:rad_emigrate/core/widgets/inline_alert.dart';
import 'package:rad_emigrate/features/booking/data/booking_repository.dart';
import 'package:rad_emigrate/features/booking/domain/entities/service_booking.dart';
import 'package:rad_emigrate/features/booking/presentation/pages/booking_page.dart';
import 'package:rad_emigrate/features/booking/presentation/pages/booking_service_page.dart';
import 'package:rad_emigrate/features/booking/presentation/providers/booking_controller.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _MockAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBookingRepository implements BookingRepository {
  _FakeBookingRepository({
    ServiceCatalogResult? catalog,
    this.history = const [],
    this.submitResult = BookingSubmitOutcome.success,
  }) : catalog =
           catalog ??
           const ServiceCatalogResult(
             services: [
               ServiceOffering(
                 id: 'built-in-consultation',
                 slug: 'consultation',
                 title: 'RAD expert consultation',
                 description: 'Talk to a RAD advisor about your situation.',
                 category: ServiceCategory.consultation,
                 fulfillment: BookingFulfillment.humanConsultation,
               ),
               ServiceOffering(
                 id: 'svc-scheduled',
                 slug: 'document-review',
                 title: 'Document review',
                 description: 'A specialist reviews your documents.',
                 category: ServiceCategory.documentReview,
                 fulfillment: BookingFulfillment.staffScheduled,
                 backendManaged: true,
               ),
             ],
             capability: BookingCapability.available,
           );

  final ServiceCatalogResult catalog;
  final List<BookingRecord> history;
  final BookingSubmitOutcome submitResult;
  int submitCount = 0;

  @override
  Future<ServiceCatalogResult> listServices({required String locale}) async =>
      catalog;

  @override
  Future<List<BookingRecord>> listMyBookings() async => history;

  @override
  Future<BookingRecord> submitBooking({
    required ServiceOffering service,
    required BookingRequest request,
    required String locale,
  }) async {
    submitCount++;
    switch (submitResult) {
      case BookingSubmitOutcome.success:
        return BookingRecord(
          id: 'fake-$submitCount',
          serviceId: service.id,
          serviceTitle: service.title,
          message: request.message,
          status: BookingStatus.submitted, // Never confirmed by a fake.
          createdAt: DateTime.now().toUtc(),
        );
      case BookingSubmitOutcome.backendUnavailable:
        throw const BookingBackendUnavailableException('submit');
      case BookingSubmitOutcome.failure:
        throw const BookingException('submit');
    }
  }
}

enum BookingSubmitOutcome { success, backendUnavailable, failure }

Widget _wrap({
  required Widget home,
  required _FakeBookingRepository repo,
  required AuthController auth,
  required SharedPreferences prefs,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      bookingRepositoryProvider.overrideWithValue(repo),
      authControllerProvider.overrideWith((ref) => auth),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AuthController> authController({bool authenticated = false}) async {
    final controller = AuthController(_MockAuthRepo());
    if (authenticated) {
      controller.applySession(
        const UserSession(
          userId: 'u1',
          token: 't1',
          authenticated: true,
          fullName: 'Test User',
        ),
      );
    }
    return controller;
  }

  Future<void> pumpBooking(
    WidgetTester tester,
    _FakeBookingRepository repo, {
    bool authenticated = false,
    Widget? home,
  }) async {
    tester.view.physicalSize = const Size(1100, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = await authController(authenticated: authenticated);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _wrap(
        home: home ?? const BookingPage(),
        repo: repo,
        auth: auth,
        prefs: prefs,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('BookingPage catalog', () {
    testWidgets('renders services and never invents prices', (tester) async {
      final repo = _FakeBookingRepository();
      await pumpBooking(tester, repo);

      expect(find.text('RAD expert consultation'), findsOneWidget);
      expect(find.text('Document review'), findsOneWidget);
      // Explicit "no prices yet" note must be present.
      expect(find.textContaining('Prices appear here only'), findsOneWidget);
      expect(find.textContaining('\$'), findsNothing);
    });

    testWidgets(
      'shows explicit backend-unavailable note when capability missing',
      (tester) async {
        final repo = _FakeBookingRepository(
          catalog: const ServiceCatalogResult(
            services: [
              ServiceOffering(
                id: 'built-in-consultation',
                slug: 'consultation',
                title: 'RAD expert consultation',
                category: ServiceCategory.consultation,
                fulfillment: BookingFulfillment.humanConsultation,
              ),
            ],
            capability: BookingCapability.backendUnavailable,
          ),
        );
        await pumpBooking(tester, repo);
        expect(
          find.textContaining('Online booking is not deployed yet'),
          findsOneWidget,
        );
      },
    );

    testWidgets('unauthenticated users see sign-in prompt for history', (
      tester,
    ) async {
      final repo = _FakeBookingRepository();
      await pumpBooking(tester, repo, authenticated: false);
      expect(find.text('Sign in to book services.'), findsOneWidget);
    });

    testWidgets('authenticated users see booking history from backend', (
      tester,
    ) async {
      final repo = _FakeBookingRepository(
        history: [
          BookingRecord(
            id: 'b1',
            serviceId: 'built-in-consultation',
            serviceTitle: 'RAD expert consultation',
            status: BookingStatus.inReview,
            createdAt: DateTime.utc(2026, 10, 18, 10),
          ),
        ],
      );
      await pumpBooking(tester, repo, authenticated: true);
      expect(find.text('My bookings'), findsOneWidget);
      expect(find.text('In review'), findsOneWidget);
    });

    testWidgets('empty history shows explicit empty state', (tester) async {
      final repo = _FakeBookingRepository(history: const []);
      await pumpBooking(tester, repo, authenticated: true);
      expect(
        find.text('You have not submitted any booking requests yet.'),
        findsOneWidget,
      );
    });
  });

  group('BookingServicePage request form', () {
    Future<void> pumpDetail(
      WidgetTester tester,
      _FakeBookingRepository repo, {
      bool authenticated = true,
    }) async {
      await pumpBooking(
        tester,
        repo,
        authenticated: authenticated,
        home: const BookingServicePage(serviceId: 'built-in-consultation'),
      );
    }

    testWidgets('shows service details and request form', (tester) async {
      final repo = _FakeBookingRepository();
      await pumpDetail(tester, repo);
      expect(find.text('RAD expert consultation'), findsOneWidget);
      expect(find.byType(AppTextField), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Submit request'), findsOneWidget);
    });

    testWidgets('empty message fails validation and no submit happens', (
      tester,
    ) async {
      final repo = _FakeBookingRepository();
      await pumpDetail(tester, repo);

      await tester.ensureVisible(
        find.widgetWithText(AppButton, 'Submit request'),
      );
      await tester.tap(find.widgetWithText(AppButton, 'Submit request'));
      await tester.pumpAndSettle();

      expect(repo.submitCount, 0);
      expect(find.text('Message is required.'), findsOneWidget);
    });

    testWidgets('short message fails min-length validation', (tester) async {
      final repo = _FakeBookingRepository();
      await pumpDetail(tester, repo);

      await tester.enterText(find.byType(TextFormField), 'short');
      await tester.tap(find.widgetWithText(AppButton, 'Submit request'));
      await tester.pumpAndSettle();

      expect(repo.submitCount, 0);
      expect(
        find.text('Message must be at least 10 characters.'),
        findsOneWidget,
      );
    });

    testWidgets('valid message submits and shows success without confirming', (
      tester,
    ) async {
      final repo = _FakeBookingRepository();
      await pumpDetail(tester, repo);

      await tester.enterText(
        find.byType(TextFormField),
        'I need help with my Germany Opportunity Card application.',
      );
      await tester.tap(find.widgetWithText(AppButton, 'Submit request'));
      await tester.pumpAndSettle();

      expect(repo.submitCount, 1);
      // Success feedback appears (backend acknowledged the request)...
      expect(find.byType(InlineAlert), findsOneWidget);
      // ...but no confirmation claim is ever displayed.
      expect(find.textContaining('Confirmed'), findsNothing);
      expect(
        find.textContaining('Submitting a request does not confirm a booking.'),
        findsOneWidget,
      );
    });

    testWidgets('backend-unavailable failure surfaces explicit message', (
      tester,
    ) async {
      final repo = _FakeBookingRepository(
        submitResult: BookingSubmitOutcome.backendUnavailable,
      );
      await pumpDetail(tester, repo);

      await tester.enterText(
        find.byType(TextFormField),
        'I need help with my Germany Opportunity Card application.',
      );
      await tester.tap(find.widgetWithText(AppButton, 'Submit request'));
      await tester.pumpAndSettle();

      expect(repo.submitCount, 1);
      expect(
        find.textContaining('Online booking is not deployed yet'),
        findsOneWidget,
      );
      expect(find.textContaining('was submitted'), findsNothing);
    });

    testWidgets('unauthenticated submit redirects instead of faking success', (
      tester,
    ) async {
      final repo = _FakeBookingRepository();
      await pumpDetail(tester, repo, authenticated: false);

      await tester.enterText(
        find.byType(TextFormField),
        'I need help with my Germany Opportunity Card application.',
      );
      final submit = find.widgetWithText(AppButton, 'Submit request');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      // No local success: repository was never called for a guest.
      expect(repo.submitCount, 0);
      expect(find.textContaining('was submitted'), findsNothing);
    });
  });

  group('responsive layout', () {
    testWidgets('booking catalog fits a mobile viewport', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeBookingRepository();
      final auth = await authController(authenticated: true);
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        _wrap(home: const BookingPage(), repo: repo, auth: auth, prefs: prefs),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('RAD expert consultation'), findsOneWidget);
    });
  });

  group('RTL layout', () {
    testWidgets('booking form renders under Persian RTL locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeBookingRepository();
      final auth = await authController(authenticated: true);
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            bookingRepositoryProvider.overrideWithValue(repo),
            authControllerProvider.overrideWith((ref) => auth),
          ],
          child: MaterialApp(
            locale: const Locale('fa'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const BookingPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('رزرو خدمات'), findsOneWidget);
      expect(find.byType(AppCard), findsWidgets);
    });
  });

  group('accessibility semantics', () {
    testWidgets('service cards expose tap semantics with labels', (
      tester,
    ) async {
      final repo = _FakeBookingRepository();
      await pumpBooking(tester, repo);

      final handle = tester.ensureSemantics();
      // The card merges title/badge/description into one semantics node, so
      // match the label as a pattern rather than an exact string.
      expect(
        find.bySemanticsLabel(RegExp('RAD expert consultation')),
        findsWidgets,
      );
      // Dispose before the binding's end-of-test handle verification.
      handle.dispose();
    });
  });
}
