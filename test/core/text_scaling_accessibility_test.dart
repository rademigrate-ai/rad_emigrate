import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/core/widgets/empty_state.dart';
import 'package:rad_emigrate/core/widgets/error_state.dart';
import 'package:rad_emigrate/core/widgets/section_header.dart';
import 'package:rad_emigrate/features/applications/domain/entities/visa_application.dart';
import 'package:rad_emigrate/features/applications/domain/repositories/application_repository.dart';
import 'package:rad_emigrate/features/applications/presentation/providers/application_controller.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document.dart';
import 'package:rad_emigrate/features/documents/domain/repositories/document_repository.dart';
import 'package:rad_emigrate/features/documents/presentation/providers/document_controller.dart';
import 'package:rad_emigrate/features/profile/presentation/pages/profile_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _MockAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAppRepo implements ApplicationRepository {
  @override
  Future<List<VisaApplication>> listApplications({String? userId}) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocRepo implements DocumentRepository {
  @override
  Future<List<Document>> listDocuments({String? userId}) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('D-09: App-wide 200% Text-Scale Accessibility Assertions', () {
    testWidgets(
      'Core UI components render without exception at 200% text scale',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('fa'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.0),
                size: Size(390, 844),
              ),
              child: Scaffold(
                body: ListView(
                  children: const [
                    SectionHeader(
                      title: 'عنوان بخش اصلی',
                      actionLabel: 'مشاهده همه',
                    ),
                    EmptyState(
                      title: 'موردی یافت نشد',
                      subtitle: 'لطفاً دوباره تلاش کنید',
                    ),
                    ErrorState(message: 'خطا در برقراری ارتباط با سرور'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('عنوان بخش اصلی'), findsOneWidget);
        expect(find.text('موردی یافت نشد'), findsOneWidget);
      },
    );

    testWidgets(
      'DashboardPage renders without overflow at 200% text scale in Persian RTL',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final auth = AuthController(_MockAuthRepo())
          ..applySession(const UserSession(authenticated: false));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authControllerProvider.overrideWith((ref) => auth),
              applicationControllerProvider.overrideWith(
                (ref) => ApplicationController(_FakeAppRepo(), null),
              ),
              documentControllerProvider.overrideWith(
                (ref) => DocumentController(_FakeDocRepo(), null),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('fa'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2.0),
                    disableAnimations: true,
                  ),
                  child: const DashboardPage(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('رزرو'), findsWidgets);
        expect(find.text('مصاحبه‌ها'), findsWidgets);
      },
    );

    testWidgets(
      'Guest ProfilePage renders without overflow at 200% text scale in English LTR',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final auth = AuthController(_MockAuthRepo())
          ..applySession(const UserSession(authenticated: false));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authControllerProvider.overrideWith((ref) => auth),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2.0),
                    disableAnimations: true,
                  ),
                  child: const ProfilePage(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Sign in'), findsOneWidget);
        expect(find.text('Create an account'), findsOneWidget);
      },
    );
  });
}
