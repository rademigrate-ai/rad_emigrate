import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/booking/data/booking_repository.dart';
import 'package:rad_emigrate/features/booking/domain/booking_validation.dart';
import 'package:rad_emigrate/features/booking/domain/entities/service_booking.dart';
import 'package:rad_emigrate/features/booking/presentation/pages/booking_page.dart';
import 'package:rad_emigrate/features/booking/presentation/providers/booking_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository({
    this.catalogResult,
    this.shouldFailUnavailable = false,
  });

  final ServiceCatalogResult? catalogResult;
  final bool shouldFailUnavailable;

  @override
  Future<ServiceCatalogResult> listServices({required String locale}) async {
    if (shouldFailUnavailable) {
      return const ServiceCatalogResult(
        services: [],
        capability: BookingCapability.backendUnavailable,
      );
    }
    return catalogResult ??
        ServiceCatalogResult(
          services: [
            ServiceOffering(
              id: 'test-consultation',
              slug: 'consultation',
              title: locale == 'fa' ? 'مشاوره تخصصی' : 'Expert consultation',
              description: 'Test description',
              category: ServiceCategory.consultation,
              fulfillment: BookingFulfillment.humanConsultation,
            ),
          ],
          capability: BookingCapability.available,
        );
  }

  @override
  Future<BookingRecord> submitBooking({
    required ServiceOffering service,
    required BookingRequest request,
    required String locale,
  }) async {
    if (shouldFailUnavailable) {
      throw const BookingBackendUnavailableException('submit_booking');
    }
    return BookingRecord(
      id: 'rec-123',
      serviceId: service.id,
      serviceTitle: service.title,
      status: BookingStatus.submitted,
      createdAt: DateTime.utc(2026, 10, 20),
    );
  }

  @override
  Future<List<BookingRecord>> listMyBookings() async {
    return [
      BookingRecord(
        id: 'rec-123',
        serviceId: 'test-consultation',
        serviceTitle: 'مشاوره آزمایشی',
        status: BookingStatus.submitted,
        createdAt: DateTime.utc(2026, 10, 20),
      ),
    ];
  }
}

class FakeAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Booking Validation Tests', () {
    test('validateMessage checks min and max lengths', () {
      expect(BookingValidation.validateMessage('').isValid, isFalse);
      expect(BookingValidation.validateMessage('short').isValid, isFalse);
      expect(
        BookingValidation.validateMessage(
          'This is a sufficiently long message.',
        ).isValid,
        isTrue,
      );
      expect(BookingValidation.validateMessage('A' * 1001).isValid, isFalse);
    });

    test('validatePreferredSlot rejects past dates or inverted range', () {
      final now = DateTime.utc(2026, 10, 20, 12, 0);
      final past = DateTime.utc(2026, 10, 19, 12, 0);
      final futureStart = DateTime.utc(2026, 10, 21, 10, 0);
      final futureEnd = DateTime.utc(2026, 10, 21, 11, 0);

      expect(
        BookingValidation.validatePreferredSlot(
          startUtc: past,
          endUtc: futureEnd,
          nowUtc: now,
        ).isValid,
        isFalse,
      );

      expect(
        BookingValidation.validatePreferredSlot(
          startUtc: futureEnd,
          endUtc: futureStart,
          nowUtc: now,
        ).isValid,
        isFalse,
      );

      expect(
        BookingValidation.validatePreferredSlot(
          startUtc: futureStart,
          endUtc: futureEnd,
          nowUtc: now,
        ).isValid,
        isTrue,
      );
    });
  });

  group('BookingPage Widget Tests', () {
    testWidgets('renders catalog correctly when unauthenticated', (
      tester,
    ) async {
      final fakeRepo = FakeBookingRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [bookingRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(
            locale: Locale('fa'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BookingPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('رزرو خدمات'), findsOneWidget);
      expect(find.text('فهرست خدمات'), findsOneWidget);
      expect(find.text('مشاوره تخصصی'), findsOneWidget);
      expect(find.text('رزروهای من'), findsNothing);
    });

    testWidgets('renders my bookings when authenticated', (tester) async {
      final fakeRepo = FakeBookingRepository();
      final auth = AuthController(FakeAuthRepo())
        ..applySession(
          const UserSession(
            userId: 'user-001',
            token: 'token-001',
            authenticated: true,
            fullName: 'Test User',
          ),
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(fakeRepo),
            authControllerProvider.overrideWith((ref) => auth),
          ],
          child: const MaterialApp(
            locale: Locale('fa'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BookingPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('رزرو خدمات'), findsOneWidget);
      expect(find.text('فهرست خدمات'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('رزروهای من'), 500);
      expect(find.text('رزروهای من'), findsOneWidget);
      expect(find.text('مشاوره آزمایشی'), findsOneWidget);
    });

    testWidgets('shows backend-unavailable banner when capability is missing', (
      tester,
    ) async {
      final fakeRepo = FakeBookingRepository(shouldFailUnavailable: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [bookingRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(
            locale: Locale('fa'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BookingPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.textContaining('سیستم رزرو آنلاین هنوز راه‌اندازی نشده است'),
        findsOneWidget,
      );
    });
  });
}
