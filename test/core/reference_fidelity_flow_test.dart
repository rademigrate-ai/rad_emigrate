import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/visual_qa_main.dart';
import 'package:rad_emigrate/features/global_time/presentation/pages/world_clock_page.dart';
import 'package:rad_emigrate/features/global_time/presentation/providers/global_time_controller.dart';
import 'package:rad_emigrate/features/global_time/presentation/widgets/reference_city_clock.dart';

Future<void> pumpScreen(WidgetTester tester, String screen) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    VisualQaApp(
      preferences: preferences,
      initialScreen: screen,
      locale: const Locale('en'),
      themeMode: ThemeMode.light,
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets(
    'persistent Explore search filters the actual catalog before selection',
    (tester) async {
      await pumpScreen(tester, 'visa');
      expect(find.byType(TextFormField), findsOneWidget);
      for (final category in ['Study', 'Work', 'Investment', 'Visit']) {
        expect(find.text(category), findsOneWidget);
      }
      await tester.enterText(find.byType(TextFormField), 'Germany');
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'Germany',
        ),
        findsOneWidget,
      );
      expect(find.text('Canada'), findsNothing);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'Germany',
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Sample study pathway'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'case filters preserve list data and open the actual status timeline',
    (tester) async {
      await pumpScreen(tester, 'cases');
      expect(find.text('Sample study pathway'), findsOneWidget);
      await tester.tap(find.text('Completed'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Sample study pathway'), findsNothing);
      await tester.tap(find.text('All cases'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Sample study pathway'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Canada'), findsOneWidget);
      expect(find.text('Update status'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('document category filtering keeps real metadata and actions', (
    tester,
  ) async {
    await pumpScreen(tester, 'documents');
    await tester.ensureVisible(
      find.widgetWithText(ChoiceChip, 'Education document'),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Education document'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sample passport'), findsNothing);
    await tester.tap(find.text('Sample academic record'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Education document'), findsWidgets);
    expect(find.text('Delete document'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'city detail follows the same selected UTC instant as city rows',
    (tester) async {
      await pumpScreen(tester, 'world-time');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WorldClockPage)),
      );
      container
          .read(globalTimeControllerProvider.notifier)
          .setScrubUtc(DateTime.utc(2026, 1, 15, 12));
      await tester.pump();
      await tester.tap(find.text('Tehran'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ReferenceCityDetail), findsOneWidget);
      expect(find.text('Asia/Tehran'), findsOneWidget);
      expect(find.text('15:30'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
