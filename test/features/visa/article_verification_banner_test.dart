import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/visa/domain/entities/canonical_pathway_entities.dart';
import 'package:rad_emigrate/features/visa/domain/entities/search_entities.dart';
import 'package:rad_emigrate/features/visa/presentation/widgets/article_change_highlights_banner.dart';

void main() {
  testWidgets('undated source never implies recent verification or approval', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArticleChangeHighlightsBanner(
            lastFactCheckedAt: null,
            sections: [],
            officialSources: [
              OfficialSourceAttribution(
                authorityName: 'Unverified source',
                authorityDomain: 'example.org',
                originalEvidenceUrl: 'https://example.org/source',
                lastFactCheckedAt: null,
                factualStatus: FactualStatus.unverified,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.textContaining('ثبت نشده'), findsOneWidget);
    expect(find.textContaining('اخیراً'), findsNothing);
    await tester.tap(find.text('منابع و وضعیت بررسی'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('به معنی تأیید قانونی یا تصویب انسانی نیست'),
      findsOneWidget,
    );
    expect(find.textContaining('بازبینی و تصویب شده است'), findsNothing);
  });
  testWidgets('date without sources does not claim every clause verified', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArticleChangeHighlightsBanner(
            lastFactCheckedAt: DateTime.utc(2026, 10, 26),
            sections: const [],
            officialSources: const [],
          ),
        ),
      ),
    );
    await tester.tap(find.text('منابع و وضعیت بررسی'));
    await tester.pumpAndSettle();
    expect(find.textContaining('انطباق قانونی احراز نشده است'), findsOneWidget);
    expect(find.textContaining('کلیه بندها مستقیماً'), findsNothing);
  });
}
