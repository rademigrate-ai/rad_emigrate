import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/supabase/supabase_providers.dart';
import 'package:rad_emigrate/features/admin/presentation/pages/admin_source_content_page.dart';
import 'package:rad_emigrate/features/visa/data/frozen_visa_content.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/mock_supabase_service.dart';

void main() {
  for (final role in ['user', 'admin', 'super_admin']) {
    test(
      'source workspace uses the owned server profile role: $role',
      () async {
        final service = await mockSupabaseService((request) async {
          expect(request.url.path, '/rest/v1/profiles');
          expect(request.url.queryParameters['id'], 'eq.$testOwner');
          return rpcJson({'id': testOwner, 'role': role});
        });
        final container = ProviderContainer(
          overrides: [
            supabaseClientServiceProvider.overrideWithValue(service),
            supabaseAuthUserIdProvider.overrideWith(
              (ref) => Stream.value(testOwner),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(supabaseAuthUserIdProvider.future);
        expect(
          await container.read(adminSourceReviewAccessProvider.future),
          role != 'user',
        );
      },
    );
  }

  test('late role response cannot authorize a signed-out session', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final service = await mockSupabaseService((request) async {
      if (request.url.path == '/rest/v1/profiles') {
        started.complete();
        await release.future;
        return rpcJson({'id': testOwner, 'role': 'admin'});
      }
      return rpcJson({});
    });
    final container = ProviderContainer(
      overrides: [
        supabaseClientServiceProvider.overrideWithValue(service),
        supabaseAuthUserIdProvider.overrideWith(
          (ref) => Stream.value(testOwner),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(supabaseAuthUserIdProvider.future);
    final access = container.read(adminSourceReviewAccessProvider.future);
    await started.future;
    await service.client.auth.signOut(scope: SignOutScope.local);
    release.complete();
    expect(await access, false);
  });
  // Decode the real bundled source data before entering Flutter fake-async.
  setUpAll(() async {
    await frozenVisaContent.reviewCatalog('en');
    await frozenVisaContent.countries('en');
  });

  testWidgets('employer source review refuses unauthenticated sessions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseAuthUserIdProvider.overrideWith(
            (ref) => Stream<String?>.value(null),
          ),
        ],
        child: const MaterialApp(home: AdminSourceContentPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Sign in with an authorized'), findsOneWidget);
    expect(find.textContaining('1,077 read-only articles'), findsNothing);
    expect(find.textContaining('Review matching'), findsNothing);
  });

  testWidgets('employer can browse immutable source index without CMS writes', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseAuthUserIdProvider.overrideWith(
            (ref) => Stream<String?>.value('authenticated-reviewer-fixture'),
          ),
          adminFrozenSourceProposalsProvider.overrideWith((ref) async => []),
          adminSourceReviewAccessProvider.overrideWith((ref) async => true),
        ],
        child: const MaterialApp(home: AdminSourceContentPage()),
      ),
    );
    // The screen also shows a retry/loading indicator during provider
    // handoff. Assert its real content instead of waiting for all animations.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .textContaining('No live CMS-bound proposal')
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(find.textContaining('1,077 read-only articles'), findsOneWidget);
    expect(find.textContaining('No live CMS-bound proposals'), findsOneWidget);
    expect(find.textContaining('Review matching research'), findsNothing);
    expect(find.text('Search articles'), findsOneWidget);
  });

  testWidgets('signed-in ordinary user cannot load proposal workspace', (
    tester,
  ) async {
    var proposalReads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseAuthUserIdProvider.overrideWith(
            (ref) => Stream.value('ordinary-user'),
          ),
          adminSourceReviewAccessProvider.overrideWith((ref) async => false),
          adminFrozenSourceProposalsProvider.overrideWith((ref) async {
            proposalReads++;
            return [];
          }),
        ],
        child: const MaterialApp(home: AdminSourceContentPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Administrator access required.'), findsOneWidget);
    expect(find.textContaining('1,077 read-only articles'), findsNothing);
    expect(proposalReads, 0);
  });

  testWidgets('role lookup error never presents a successful workspace', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseAuthUserIdProvider.overrideWith(
            (ref) => Stream.value('expired-session'),
          ),
          adminSourceReviewAccessProvider.overrideWith(
            (ref) async => throw StateError('denied'),
          ),
        ],
        child: const MaterialApp(home: AdminSourceContentPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Administrator access could not be verified.'),
      findsOneWidget,
    );
    expect(find.text('Retry access check'), findsOneWidget);
    expect(find.textContaining('Review matching research'), findsNothing);
  });

  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('authorized source workspace renders at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseAuthUserIdProvider.overrideWith(
              (ref) => Stream.value('admin-fixture'),
            ),
            adminSourceReviewAccessProvider.overrideWith((ref) async => true),
            adminFrozenSourceProposalsProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: AdminSourceContentPage()),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Three-Site Source Review'), findsOneWidget);
      expect(find.textContaining('1,077 read-only articles'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
