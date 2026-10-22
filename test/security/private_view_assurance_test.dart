import 'package:rad_emigrate/app/dependencies.dart';
import 'package:rad_emigrate/core/routing/app_router.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rad_emigrate/core/supabase/supabase_client.dart';
import 'package:rad_emigrate/core/supabase/supabase_providers.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/profile/domain/entities/user_profile.dart';
import 'package:rad_emigrate/features/profile/domain/entities/profile_entity.dart';
import 'package:rad_emigrate/features/profile/domain/repositories/profile_repository.dart';
import 'package:rad_emigrate/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:rad_emigrate/features/profile/data/datasources/immigration_profile_local_datasource.dart';
import 'package:rad_emigrate/features/profile/data/repositories/immigration_profile_repository_impl.dart';
import 'package:rad_emigrate/features/profile/presentation/pages/profile_page.dart';
import 'package:rad_emigrate/features/profile/presentation/pages/immigration_profile_page.dart';
import 'package:rad_emigrate/features/profile/presentation/providers/profile_controller.dart';
import 'package:rad_emigrate/features/profile/presentation/providers/immigration_profile_controller.dart';
import 'package:rad_emigrate/features/applications/data/datasources/application_local_datasource.dart';
import 'package:rad_emigrate/features/applications/domain/entities/visa_application.dart';
import 'package:rad_emigrate/features/applications/domain/entities/application_status.dart';
import 'package:rad_emigrate/features/notifications/data/notification_reader.dart';
import 'package:rad_emigrate/features/notifications/presentation/pages/notifications_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

const a = 'a1111111-1111-4111-8111-111111111111',
    b = 'b1111111-1111-4111-8111-111111111111';
final identityProvider = StateProvider<String?>((ref) => a);

class _Auth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Profiles implements ProfileRepository {
  @override
  Future<UserProfile?> getProfile(String id) async =>
      UserProfile(id: id, firstName: 'PRIVATE_$id');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

AuthController mirror() => AuthController(_Auth())
  ..applySession(
    const UserSession(
      userId: a,
      authenticated: true,
      token: 'synthetic-only',
      fullName: 'PRIVATE_A_MIRROR',
    ),
  );
Widget root(ProviderContainer container, Widget page) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: page,
      ),
    );
Map<String, dynamic> notice(String title) => {
  'id': 'c1111111-1111-4111-8111-111111111111',
  'type': 'system',
  'title': title,
  'body': 'synthetic',
  'action_path': null,
  'read_at': null,
  'created_at': '2026-10-21T10:00:00Z',
};

class _Service implements SupabaseClientService {
  _Service(this.client);
  @override
  final SupabaseClient client;
  @override
  bool get isInitialized => true;
  @override
  Object? initializationError;
  @override
  Future<bool> initialize() async => true;
}

Future<void> activate(SupabaseClient client, String id) async {
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final token =
      '${enc({'alg': 'none'})}.${enc({'sub': id, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.synthetic';
  await client.auth.recoverSession(
    jsonEncode({
      'access_token': token,
      'refresh_token': 'synthetic-only',
      'expires_in': 3600,
      'token_type': 'bearer',
      'user': {
        'id': id,
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-01-01T00:00:00Z',
      },
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('applications reject unscoped and wrong-owner cache rows', () async {
    final prefs = await SharedPreferences.getInstance();
    final cache = ApplicationLocalDataSource(prefs);
    final item = VisaApplication(
      id: 'case',
      title: 'PRIVATE_A',
      programName: 'synthetic',
      country: 'ZZ',
      status: ApplicationStatus.draft,
      updatedAt: DateTime.utc(2026),
      userId: a,
    );
    await prefs.setString('rad_applications', jsonEncode([item.toJson()]));
    expect(await cache.readAll(), isEmpty);
    await cache.writeForUser(a, [item]);
    expect((await cache.readForUser(a)).single.userId, a);
    expect(await cache.readForUser(b), isEmpty);
    await prefs.setString('rad_applications_$b', jsonEncode([item.toJson()]));
    expect(await cache.readForUser(b), isEmpty);
  });
  test(
    'profile cache rejects a different owner under the requested key',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final cache = ProfileLocalDataSource(prefs);
      const profile = UserProfile(id: a, firstName: 'PRIVATE_A');
      await cache.write(profile);
      await prefs.setString('rad_profile_$b', jsonEncode(profile.toJson()));
      expect(await cache.read(b), isNull);
      expect((await cache.read(a))?.id, a);
    },
  );
  testWidgets(
    'public Profile editor discards private A form and mirror metadata on account change',
    (tester) async {
      final auth = mirror();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          authenticatedUserIdProvider.overrideWith(
            (ref) => ref.watch(identityProvider),
          ),
          authControllerProvider.overrideWith((ref) => auth),
          profileRepositoryProvider.overrideWithValue(_Profiles()),
        ],
      );
      try {
        await tester.pumpWidget(root(container, const ProfilePage()));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'PRIVATE_A_UNSAVED',
        );
        container.read(identityProvider.notifier).state = null;
        await tester.pumpAndSettle();
        expect(auth.current.userId, a);
        expect(find.text('PRIVATE_A_UNSAVED'), findsNothing);
        expect(find.textContaining('PRIVATE_A_MIRROR'), findsNothing);
        container.read(identityProvider.notifier).state = b;
        auth.applySession(
          const UserSession(
            userId: b,
            authenticated: true,
            token: 'synthetic-only',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('PRIVATE_$b'), findsWidgets);
        expect(find.text('PRIVATE_A_UNSAVED'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    },
  );
  testWidgets('immigration editor reads B own draft and drops unsaved A text', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final local = ImmigrationProfileLocalDataSource(prefs);
    await local.write(
      a,
      const ImmigrationProfile(fullName: 'PRIVATE_PROFILE_A'),
    );
    await local.write(
      b,
      const ImmigrationProfile(fullName: 'PRIVATE_PROFILE_B'),
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authenticatedUserIdProvider.overrideWith(
          (ref) => ref.watch(identityProvider),
        ),
        authControllerProvider.overrideWith((ref) => mirror()),
        immigrationProfileRepositoryProvider.overrideWithValue(
          ImmigrationProfileRepositoryImpl(local: local),
        ),
      ],
    );
    try {
      await tester.pumpWidget(root(container, const ImmigrationProfilePage()));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'PRIVATE_A_UNSAVED',
      );
      container.read(identityProvider.notifier).state = b;
      await tester.pumpAndSettle();
      expect(find.text('PRIVATE_A_UNSAVED'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller
            ?.text,
        'PRIVATE_PROFILE_B',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    }
  });
  testWidgets(
    'mounted notification center drops late A data and clears B data on logout',
    (tester) async {
      final pendingA = Completer<List<Map<String, dynamic>>>();
      final calls = <String>[];
      final container = ProviderContainer(
        overrides: [
          authenticatedUserIdProvider.overrideWith(
            (ref) => ref.watch(identityProvider),
          ),
          authControllerProvider.overrideWith((ref) => mirror()),
          notificationReaderProvider.overrideWithValue((id) {
            calls.add(id);
            return id == a
                ? pendingA.future
                : Future.value([notice('PRIVATE_NOTICE_B')]);
          }),
        ],
      );
      try {
        await tester.pumpWidget(root(container, const NotificationsPage()));
        await tester.pump();
        expect(calls, contains(a));
        container.read(identityProvider.notifier).state = b;
        await tester.pumpAndSettle();
        expect(find.text('PRIVATE_NOTICE_B'), findsOneWidget);
        pendingA.complete([notice('PRIVATE_NOTICE_A')]);
        await tester.pumpAndSettle();
        expect(find.text('PRIVATE_NOTICE_A'), findsNothing);
        expect(find.text('PRIVATE_NOTICE_B'), findsOneWidget);
        container.read(identityProvider.notifier).state = null;
        await tester.pumpAndSettle();
        expect(find.text('PRIVATE_NOTICE_B'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    },
  );
  testWidgets(
    'router reacts to verified logout and denies an authenticated mirror without an identity',
    (tester) async {
      for (final missingIdentity in [false, true]) {
        final auth = AuthController(_Auth())
          ..applySession(
            UserSession(
              userId: missingIdentity ? null : a,
              authenticated: true,
              token: 'synthetic-only',
              profileComplete: true,
            ),
          );
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
            authControllerProvider.overrideWith((ref) => auth),
            authenticatedUserIdProvider.overrideWith(
              (ref) => ref.watch(identityProvider),
            ),
            appBootstrapProvider.overrideWith((ref) async {}),
          ],
        );
        container.read(identityProvider.notifier).state = missingIdentity
            ? null
            : a;
        await container.read(appBootstrapProvider.future);
        final router = container.read(appRouterProvider)..go('/documents');
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(
                routerConfig: router,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              ),
            ),
          );
          for (var frame = 0; frame < 8; frame++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          if (!missingIdentity) {
            expect(
              router.routeInformationProvider.value.uri.path,
              '/documents',
            );
            container.read(identityProvider.notifier).state = null;
            for (var frame = 0; frame < 8; frame++) {
              await tester.pump(const Duration(milliseconds: 50));
            }
            expect(auth.current.userId, a);
          }
          expect(router.routeInformationProvider.value.uri.path, '/login');
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
          container.dispose();
        }
      }
    },
  );
  test(
    'actual SDK notification reader fences actor filter and late replies',
    () async {
      final pendingA = Completer<List<Map<String, dynamic>>>();
      final calls = <String>[];
      final client = SupabaseClient(
        'http://127.0.0.1:59999',
        'synthetic-only',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          var body = '{}';
          if (request.url.path.endsWith('/notifications')) {
            final owner = request.url.queryParameters['user_id']!;
            calls.add(owner);
            body = jsonEncode(
              owner == 'eq.$a'
                  ? await pendingA.future
                  : [notice('PRIVATE_NOTICE_B')],
            );
          }
          return http.Response(
            body,
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      await activate(client, a);
      final container = ProviderContainer(
        overrides: [
          supabaseClientServiceProvider.overrideWithValue(_Service(client)),
          authControllerProvider.overrideWith((ref) => mirror()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(supabaseAuthUserIdProvider.future);
      final reader = container.read(notificationReaderProvider);
      final first = reader(a);
      await Future<void>.delayed(Duration.zero);
      await client.auth.signOut(scope: SignOutScope.local);
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      pendingA.complete([notice('PRIVATE_NOTICE_A')]);
      expect(await first, isEmpty);
      await activate(client, b);
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      expect((await reader(b)).single['title'], 'PRIVATE_NOTICE_B');
      final before = calls.length;
      await expectLater(reader(a), throwsStateError);
      expect(calls.length, before);
      expect(calls, ['eq.$a', 'eq.$b']);
    },
  );
}
