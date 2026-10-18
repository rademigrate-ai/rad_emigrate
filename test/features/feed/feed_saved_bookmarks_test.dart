import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/feed/data/feed_repository.dart';
import 'package:rad_emigrate/features/feed/presentation/pages/feed_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _MockAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFeedRepo implements FeedRepository {
  _FakeFeedRepo(this.items);

  List<FeedEntry> items;
  int setSavedCalls = 0;
  String? lastSavedId;
  bool? lastSavedValue;
  int markReadCalls = 0;
  String? lastReadId;

  @override
  Future<List<FeedEntry>> load(String locale, {int limit = 50}) async => items;

  @override
  Future<void> setSaved(String itemId, bool value) async {
    setSavedCalls++;
    lastSavedId = itemId;
    lastSavedValue = value;
    final idx = items.indexWhere((e) => e.id == itemId);
    if (idx != -1) {
      final old = items[idx];
      items[idx] = FeedEntry(
        id: old.id,
        slug: old.slug,
        category: old.category,
        title: old.title,
        summary: old.summary,
        saved: value,
        sourceUrl: old.sourceUrl,
        publishedAt: old.publishedAt,
      );
    }
  }

  @override
  Future<void> markRead(String itemId) async {
    markReadCalls++;
    lastReadId = itemId;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testEntry = FeedEntry(
    id: 'entry-1',
    slug: 'express-entry-draw',
    category: 'Express Entry',
    title: 'Canada Express Entry Minimum CRS Drops',
    summary: 'New category-based selection draw details.',
    saved: false,
    publishedAt: DateTime(2026, 10, 18),
  );

  testWidgets(
    'unauthenticated user tapping bookmark redirects to login with return path',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      final auth = AuthController(_MockAuthRepo());
      final repo = _FakeFeedRepo([testEntry]);

      final router = GoRouter(
        initialLocation: '/feed',
        routes: [
          GoRoute(path: '/feed', builder: (context, state) => const FeedPage()),
          GoRoute(
            path: '/login',
            builder: (context, state) =>
                Text('LOGIN_SCREEN: from=${state.uri.queryParameters['from']}'),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith((ref) => auth),
            feedRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Canada Express Entry Minimum CRS Drops'),
        findsOneWidget,
      );
      final bookmarkIcon = find.byIcon(Icons.bookmark_border);
      expect(bookmarkIcon, findsOneWidget);

      await tester.tap(bookmarkIcon);
      await tester.pumpAndSettle();

      // Must navigate to login with query param from=/feed
      expect(find.text('LOGIN_SCREEN: from=/feed'), findsOneWidget);
      expect(repo.setSavedCalls, 0);
    },
  );

  testWidgets(
    'authenticated user tapping bookmark toggles saved state and invalidates feed provider',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      final auth = AuthController(_MockAuthRepo())
        ..applySession(
          const UserSession(
            userId: 'user-123',
            token: 'valid-jwt-token',
            authenticated: true,
            fullName: 'Test Applicant',
          ),
        );
      final repo = _FakeFeedRepo([testEntry]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith((ref) => auth),
            feedRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const FeedPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bookmarkBorder = find.byIcon(Icons.bookmark_border);
      expect(bookmarkBorder, findsOneWidget);

      await tester.tap(bookmarkBorder);
      await tester.pumpAndSettle();

      expect(repo.setSavedCalls, 1);
      expect(repo.lastSavedId, 'entry-1');
      expect(repo.lastSavedValue, isTrue);

      // Now it should show filled bookmark icon
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    },
  );

  testWidgets('tapping card triggers markRead tracking', (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final auth = AuthController(_MockAuthRepo());
    final repo = _FakeFeedRepo([testEntry]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authControllerProvider.overrideWith((ref) => auth),
          feedRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const FeedPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardTitle = find.text('Canada Express Entry Minimum CRS Drops');
    await tester.tap(cardTitle);
    await tester.pumpAndSettle();

    expect(repo.markReadCalls, 1);
    expect(repo.lastReadId, 'entry-1');
  });
}
