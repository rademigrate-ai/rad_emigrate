import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/supabase/supabase_providers.dart';
import 'package:rad_emigrate/features/admin/presentation/pages/admin_source_content_page.dart';
import 'package:rad_emigrate/features/visa/data/frozen_visa_content.dart';

void main() {
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
}
