// Widget tests for the Immigration Cost Calculator page.
//
// The visa repository is overridden with a deterministic fake so no test hits
// a live Backend. The assertions pin the truthfulness contract: a figure is
// only shown when the catalog published one, and "not published" appears
// verbatim otherwise.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/cost_calculator/presentation/pages/cost_calculator_page.dart';
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
  title: 'Study permit — Government of Canada',
  url: 'https://www.canada.ca/study',
  publisher: 'Canada.ca',
  retrievedAt: DateTime(2026, 1, 15),
);

VisaCatalog _catalog({String? fees, String? processingTime}) {
  return VisaCatalog(
    countries: const [
      Country(
        id: 'ca',
        name: 'Canada',
        code: 'CA',
        flagEmoji: '🇨🇦',
        slug: 'canada',
      ),
    ],
    categories: const [
      VisaCategory(
        id: 'study',
        name: 'Study permit',
        description: '',
        slug: 'study',
      ),
    ],
    programs: [
      VisaProgram(
        id: 'p1',
        slug: 'study-permit',
        title: 'Study permit (first-time)',
        countryId: 'ca',
        categoryId: 'study',
        summary: 'Study permit for first-time applicants.',
        fees: fees,
        processingTime: processingTime,
        source: _source,
      ),
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
        home: const CostCalculatorPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a published figure with its source wording', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeVisaRepository(_catalog(fees: 'CAD 150', processingTime: '8 weeks')),
    );

    // Select the only pathway so the breakdown renders.
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇨🇦 Canada · Study permit').last);
    await tester.pumpAndSettle();

    expect(find.text('CAD 150'), findsWidgets);
    expect(find.textContaining('Parsed from catalog text'), findsWidgets);
    expect(find.textContaining('Government of Canada'), findsOneWidget);
    expect(find.textContaining('Not published'), findsNothing);
  });

  testWidgets('shows explicit not-published state when no fee is published', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeVisaRepository(_catalog(processingTime: '8 weeks')),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇨🇦 Canada · Study permit').last);
    await tester.pumpAndSettle();

    expect(
      find.text('No parseable figure is available in the catalog.'),
      findsOneWidget,
    );
    // Currency chips legitimately show symbols; a rendered *amount* would
    // contain a digit right after the symbol (e.g. "$150").
    expect(find.textContaining('\$1'), findsNothing);
  });

  testWidgets('renders prose-only fees without inventing a number', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeVisaRepository(
        _catalog(fees: 'from \$100 to \$200 depending on category'),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇨🇦 Canada · Study permit').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('from \$100 to \$200'), findsOneWidget);
    expect(find.textContaining('not an exact figure'), findsWidgets);
    // No invented figure: the line shows a dash and the total stays unavailable.
    expect(find.text('—'), findsOneWidget);
    expect(
      find.text('No parseable figure is available to subtotal.'),
      findsOneWidget,
    );
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
    expect(find.textContaining('Sign in to view the catalog'), findsOneWidget);
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
    expect(find.textContaining('Loading cost data failed'), findsOneWidget);
  });

  testWidgets('shows empty state when catalog has no pathways', (tester) async {
    await _pump(
      tester,
      _FakeVisaRepository(
        const VisaCatalog(countries: [], categories: [], programs: []),
      ),
    );
    expect(
      find.textContaining('No published pathway is available for cost'),
      findsOneWidget,
    );
  });
}
