import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/empty_state.dart';
import 'package:rad_emigrate/core/widgets/error_state.dart';
import 'package:rad_emigrate/core/widgets/loading_state.dart';
import 'package:rad_emigrate/features/feed/data/feed_repository.dart';
import 'package:rad_emigrate/features/feed/presentation/pages/feed_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

Future<void> frames(WidgetTester t, [int n = 12]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Widget app(List<Override> overrides, Widget child) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('EQS-FEED loading shows LoadingState', (tester) async {
    final completer = Completer<List<FeedEntry>>();
    await tester.pumpWidget(
      app([
        feedProvider.overrideWith((ref, locale) => completer.future),
      ], const FeedPage()),
    );
    await tester.pump();
    expect(find.byType(LoadingState), findsWidgets);
    completer.complete(const []);
    await frames(tester);
  });

  testWidgets('EQS-FEED error shows ErrorState and retry', (tester) async {
    await tester.pumpWidget(
      app([
        feedProvider.overrideWith((ref, locale) async {
          throw Exception('down');
        }),
      ], const FeedPage()),
    );
    await frames(tester, 20);
    expect(find.byType(ErrorState), findsOneWidget);
    expect(
      find.text(lookupAppLocalizations(const Locale('en')).retry),
      findsOneWidget,
    );
  });

  testWidgets('EQS-FEED empty shows EmptyState', (tester) async {
    await tester.pumpWidget(
      app([
        feedProvider.overrideWith((ref, locale) async => const <FeedEntry>[]),
      ], const FeedPage()),
    );
    await frames(tester, 20);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('EQS-FEED data renders published title', (tester) async {
    await tester.pumpWidget(
      app([
        feedProvider.overrideWith(
          (ref, locale) async => [
            FeedEntry(
              id: '1',
              slug: 'brief-1',
              category: 'news',
              title: 'Published briefing',
              summary: 'Summary text',
              saved: false,
              publishedAt: DateTime.utc(2026, 2, 1),
            ),
          ],
        ),
      ], const FeedPage()),
    );
    await frames(tester, 25);
    expect(find.text('Published briefing'), findsOneWidget);
  });
}
