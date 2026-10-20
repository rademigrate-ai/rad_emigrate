import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/services/ai/ai_response.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/widgets/ai_citation_card.dart';

void main() {
  group('AI Citation Card Tests', () {
    testWidgets('renders index, authority, title, domain, and verified badge', (
      tester,
    ) async {
      const source = AiSource(
        title: 'قوانین کارت فرصت آلمان',
        authority: 'Make it in Germany',
        url: 'https://make-it-in-germany.com/en/visa-residence/types/chancenkarte',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AiCitationCard(index: 1, source: source)),
        ),
      );

      expect(find.text('[1]'), findsOneWidget);
      expect(find.text('قوانین کارت فرصت آلمان'), findsOneWidget);
      expect(find.text('Make it in Germany'), findsOneWidget);
      expect(find.text('make-it-in-germany.com'), findsOneWidget);
      expect(find.text('منبع رسمی'), findsOneWidget);
    });

    testWidgets('handles source without authority or url safely', (
      tester,
    ) async {
      const source = AiSource(title: 'منبع عمومی بدون پیوند');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AiCitationCard(index: 2, source: source)),
        ),
      );

      expect(find.text('[2]'), findsOneWidget);
      expect(find.text('منبع عمومی بدون پیوند'), findsOneWidget);
      expect(find.text('منبع رسمی'), findsOneWidget);
    });
  });
}
