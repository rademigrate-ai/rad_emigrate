import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/supabase/supabase_client.dart';
import 'package:rad_emigrate/features/admin/data/admin_ai_config_repository.dart';
import 'package:rad_emigrate/features/admin/data/admin_operations_repository.dart';
import 'package:rad_emigrate/features/admin/presentation/admin_ai_labels.dart';
import 'package:rad_emigrate/features/admin/presentation/pages/admin_ai_config_page.dart';
import 'package:rad_emigrate/features/admin/presentation/pages/admin_source_dialog.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';
import 'package:rad_emigrate/l10n/app_localizations_fa.dart';

const _provider = AdminProviderRecord(
  id: 'provider',
  slug: 'example',
  displayName: 'Provider',
  adapter: 'openai_compatible',
  baseUrl: 'https://example.org',
  enabled: true,
  priority: 10,
  runtimeScope: 'both',
  credentialConfigured: true,
  credentialRejected: true,
  healthStatus: 'offline',
  lastSuccessAt: null,
  lastFailureAt: null,
);
const _model = AdminModelRecord(
  id: 'model',
  providerId: 'provider',
  slug: 'example-model',
  displayName: 'Example model',
  capability: 'chat',
  enabled: true,
  maxOutputTokens: 100,
  runtimeScope: 'both',
  priority: 10,
  available: true,
);

AdminConsoleData _data({bool models = false}) => AdminConsoleData(
  providers: models ? [_provider] : [],
  models: models ? [_model] : [],
  sources: [],
  researchSources: [],
  researchJobs: [],
  reviews: [],
  feedItems: [],
  health: [],
  audit: [],
);

class _Sources extends AdminOperationsRepository {
  _Sources() : super(SupabaseClientService.instance);
  int calls = 0;
  bool fail = true;
  String? savedUrl;
  @override
  Future<void> createResearchSource({
    required String displayName,
    required String baseUrl,
    required String sourceType,
    required String trustClass,
    required String runtimeScope,
  }) async {
    calls++;
    if (fail) throw StateError('private upstream details');
    savedUrl = baseUrl;
  }
}

class _Models extends AdminAiConfigRepository {
  _Models() : super(SupabaseClientService.instance);
  bool fail = true;
  bool? savedEnabled;
  int calls = 0;
  @override
  Future<void> configureModel({
    required String modelId,
    required bool enabled,
    required String runtimeScope,
    required int priority,
    required int maxOutputTokens,
  }) async {
    calls++;
    if (fail) throw StateError('private upstream details');
    savedEnabled = enabled;
  }
}

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  testWidgets(
    'Source rejects unusable URL and retains form on failure for safe retry',
    (tester) async {
      final repository = _Sources();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminOperationsRepositoryProvider.overrideWithValue(repository),
            adminConsoleProvider.overrideWith((ref) async => _data()),
          ],
          child: _app(
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAdminSourceDialog(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Official source',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'https://127.0.0.1',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repository.calls, 0);
      expect(find.text('Enter a valid public HTTPS address'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'https://EXAMPLE.org/path/',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(find.text('Official source'), findsOneWidget);
      expect(find.text('private upstream details'), findsNothing);
      repository.fail = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repository.savedUrl, 'https://example.org/path');
      expect(find.byType(AdminSourceDialog), findsNothing);
    },
  );

  testWidgets(
    'failed model save keeps changed settings in dialog and permits retry',
    (tester) async {
      final repository = _Models();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAiConfigRepositoryProvider.overrideWithValue(repository),
            adminConsoleProvider.overrideWith(
              (ref) async => _data(models: true),
            ),
          ],
          child: _app(const AdminAiConfigPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('example-model'));
      await tester.pumpAndSettle();
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'Opening model settings must not start provider submission',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(
        find.text(
          'Could not save model settings. Your changes are retained; try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('private upstream details'), findsNothing);
      repository.fail = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repository.savedEnabled, false);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Admin labels localize known categories and suppress arbitrary diagnostics',
    () {
      final fa = AppLocalizationsFa();
      expect(adminHealthLabel('offline', fa), 'قطع ارتباط');
      expect(adminRuntimeScopeLabel('both', fa), 'کاربر و مدیر');
      expect(
        adminAiErrorLabel('provider_unauthorized', fa),
        fa.aiCredentialRejected,
      );
      expect(
        adminAiErrorLabel('credential-secret-from-upstream', fa),
        fa.aiRequestFailed,
      );
    },
  );
}
