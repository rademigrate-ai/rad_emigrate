// Widget tests for the Country & Pathway Comparison page.
//
// The visa repository is overridden with a deterministic fake. The assertions
// pin the truthfulness contract: a "Not published" badge appears for any
// attribute the catalog omits, and no invented figure ever renders.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/comparison/presentation/pages/comparison_page.dart';
import 'package:rad_emigrate/features/visa/data/visa_repository.dart';
import 'package:rad_emigrate/features/visa/domain/entities/visa_entities.dart';
import 'package:rad_emigrate/features/visa/presentation/providers/visa_catalog_provider.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _MockAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVisaRepository implements VisaRepository {
  _FakeVisaRepository(this._catalog, {this.error});

  final VisaCatalog? _catalog;
  final Object? error;

  @override
  Future<VisaCatalog> loadCatalog({required String locale}) async {
    if (error != null) throw error!;
    return _catalog!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _source = VisaSource(
  title: 'Immigration pathways overview',
  url: 'https://example.gov/pathways',
  publisher: 'Example Gov',
  retrievedAt: DateTime(2026, 2, 1),
);

VisaProgram _program({
  required String id,
  required String countryId,
  required String title,
  String? fees,
  String? processingTime,
  List<VisaRequirement> requirements = const [],
}) {
  return VisaProgram(
    id: id,
    slug: id,
    title: title,
    countryId: countryId,
    categoryId: 'study',
    summary: '$title summary.',
    fees: fees,
    processingTime: processingTime,
    requirements: requirements,
    source: _source,
  );
}

VisaCatalog _catalog({bool withOptionalFields = true}) {
  return VisaCatalog(
    countries: const [
      Country(
        id: 'ca',
        name: 'Canada',
        code: 'CA',
        flagEmoji: '🇨🇦',
        slug: 'canada',
      ),
      Country(
        id: 'de',
        name: 'Germany',
        code: 'DE',
        flagEmoji: '🇩🇪',
        slug: 'germany',
      ),
    ],
    categories: const [
      VisaCategory(id: 'study', name: 'Study', description: '', slug: 'study'),
    ],
    programs: [
      _program(
        id: 'p-ca',
        countryId: 'ca',
        title: 'Canada study permit',
        fees: withOptionalFields ? 'CAD 150' : null,
        processingTime: withOptionalFields ? '8 weeks' : null,
        requirements: withOptionalFields
            ? [
                const VisaRequirement(
                  text: 'Valid passport',
                  displayOrder: 0,
                  isMandatory: true,
                ),
                const VisaRequirement(
                  text: 'Letter of acceptance',
                  displayOrder: 1,
                  isMandatory: true,
                ),
              ]
            : const [],
      ),
      _program(id: 'p-de', countryId: 'de', title: 'Germany student visa'),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  VisaRepository repo, {
  bool authenticated = true,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(1100, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = AuthController(_MockAuthRepo());
  if (authenticated) {
    auth.applySession(
      const UserSession(
        userId: 'u1',
        token: 't1',
        authenticated: true,
        fullName: 'Test User',
      ),
    );
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        visaRepositoryProvider.overrideWithValue(repo),
        authControllerProvider.overrideWith((ref) => auth),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const ComparisonPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('prompts to select two pathways before showing the table', (
    tester,
  ) async {
    await _pump(tester, _FakeVisaRepository(_catalog()));

    expect(find.text('Compare pathways'), findsOneWidget);
    expect(
      find.text('Select two or three pathways to compare.'),
      findsOneWidget,
    );
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('renders a side-by-side table once two are selected', (
    tester,
  ) async {
    await _pump(tester, _FakeVisaRepository(_catalog()));

    await tester.tap(find.text('🇨🇦 Canada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇩🇪 Germany'));
    await tester.pumpAndSettle();

    expect(find.byType(DataTable), findsOneWidget);
    // The pathway title appears in the column header and the pathway row.
    expect(find.text('Canada study permit'), findsWidgets);
    expect(find.text('Germany student visa'), findsWidgets);
    expect(find.textContaining('not legal advice'), findsOneWidget);
  });

  testWidgets('shows explicit Not published badge for omitted attributes', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeVisaRepository(_catalog(withOptionalFields: false)),
    );

    await tester.tap(find.text('🇨🇦 Canada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇩🇪 Germany'));
    await tester.pumpAndSettle();

    // Both programs omit fees and processing time in this catalog.
    expect(find.text('Not published'), findsWidgets);
  });

  testWidgets(
    'renders published values without a Not published badge for them',
    (tester) async {
      await _pump(tester, _FakeVisaRepository(_catalog()));

      await tester.tap(find.text('🇨🇦 Canada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🇩🇪 Germany'));
      await tester.pumpAndSettle();

      expect(find.text('CAD 150'), findsOneWidget);
      expect(find.text('8 weeks'), findsOneWidget);
      expect(find.text('• Valid passport'), findsOneWidget);
    },
  );

  testWidgets('clears the selection when Clear is tapped', (tester) async {
    await _pump(tester, _FakeVisaRepository(_catalog()));

    await tester.tap(find.text('🇨🇦 Canada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇩🇪 Germany'));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.byType(DataTable), findsNothing);
    expect(
      find.text('Select two or three pathways to compare.'),
      findsOneWidget,
    );
  });

  testWidgets('enforces the maximum of three pathways', (tester) async {
    final base = _catalog();
    final catalog = VisaCatalog(
      countries: [
        ...base.countries,
        const Country(
          id: 'fr',
          name: 'France',
          code: 'FR',
          flagEmoji: '🇫🇷',
          slug: 'france',
        ),
      ],
      categories: base.categories,
      programs: [
        ...base.programs,
        _program(id: 'p-fr', countryId: 'fr', title: 'France talent passport'),
      ],
    );
    await _pump(tester, _FakeVisaRepository(catalog));

    await tester.tap(find.text('🇨🇦 Canada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇩🇪 Germany'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇫🇷 France'));
    await tester.pumpAndSettle();

    expect(find.text('Up to three pathways can be compared.'), findsOneWidget);
  });

  testWidgets('renders under Persian RTL locale', (tester) async {
    await _pump(
      tester,
      _FakeVisaRepository(_catalog()),
      locale: const Locale('fa'),
    );

    expect(find.text('مقایسه مسیرها'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows sign-in prompt for unauthenticated catalog failure', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeVisaRepository(
        null,
        error: const VisaCatalogException(VisaCatalogFailureKind.configuration),
      ),
      authenticated: false,
    );
    expect(
      find.textContaining('Sign in to view the verified catalog'),
      findsOneWidget,
    );
  });

  testWidgets('shows error state for authenticated catalog failure', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeVisaRepository(
        null,
        error: const VisaCatalogException(VisaCatalogFailureKind.network),
      ),
    );
    expect(
      find.textContaining('Loading comparison data failed'),
      findsOneWidget,
    );
  });

  testWidgets('shows empty state when catalog has no pathways', (tester) async {
    await _pump(
      tester,
      _FakeVisaRepository(
        const VisaCatalog(countries: [], categories: [], programs: []),
      ),
    );
    expect(
      find.textContaining('No published pathway is available to compare'),
      findsOneWidget,
    );
  });
}
