import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/visa/domain/entities/canonical_pathway_entities.dart';
import 'package:rad_emigrate/features/visa/domain/entities/search_entities.dart';
import 'package:rad_emigrate/features/visa/presentation/widgets/article_change_highlights_banner.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'ArticleChangeHighlightsBanner renders official citations and expands details',
    (tester) async {
      final sources = [
        OfficialSourceAttribution(
          authorityName: 'Federal Foreign Office Germany',
          authorityDomain: 'auswaertiges-amt.de',
          originalEvidenceUrl: 'https://auswaertiges-amt.de/visa-rules',
          lastFactCheckedAt: DateTime(2026, 10, 24),
          factualStatus: FactualStatus.verified,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ArticleChangeHighlightsBanner(
              lastFactCheckedAt: DateTime(2026, 10, 24),
              officialSources: sources,
              sections: const [],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify banner header
      expect(find.text('منابع و وضعیت بررسی'), findsOneWidget);
      expect(
        find.textContaining('Federal Foreign Office Germany'),
        findsOneWidget,
      );

      // Expand details
      await tester.tap(find.text('منابع و وضعیت بررسی'));
      await tester.pumpAndSettle();

      expect(find.text('منابع ثبت‌شده برای این نسخه:'), findsOneWidget);
      expect(find.text('دامنه منبع: auswaertiges-amt.de'), findsOneWidget);
      expect(
        find.textContaining(
          'وجود منبع یا تاریخ به‌تنهایی به معنی تأیید قانونی یا تصویب انسانی نیست',
        ),
        findsOneWidget,
      );
    },
  );
}
