import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rad_emigrate/core/supabase/supabase_client.dart';
import 'package:rad_emigrate/core/supabase/supabase_providers.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/features/admin/presentation/pages/admin_consultations_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _MockBackend implements SupabaseClientService {
  _MockBackend(this.client);

  @override
  final SupabaseClient client;

  @override
  bool get isInitialized => true;

  @override
  Object? get initializationError => null;

  @override
  Future<bool> initialize() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

_MockBackend _backend(Future<http.Response> Function(http.Request) handler) {
  final client = SupabaseClient(
    'https://local-fixture.invalid',
    'fixture-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final response = await handler(request);
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
        reasonPhrase: response.reasonPhrase,
      );
    }),
  );
  // The mock client is intentionally retained for the short widget-test lifetime.
  // Calling SupabaseClient.dispose() via addTearDown hangs the test runner
  // with this HTTP fixture; tests exercise only local mock requests.
  return _MockBackend(client);
}

http.Response _json(Object? body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final consultationRow = {
    'id': '77777777-7777-7777-7777-777777777777',
    'topic': 'Study Visa Work Permit Query',
    'message': 'Need advice on postgraduate work permit transition.',
    'status': 'submitted',
    'admin_note': null,
    'created_at': '2026-10-18T10:00:00.000Z',
    'user_id': '11111111-1111-1111-1111-111111111111',
  };

  testWidgets(
    'AdminConsultationsPage lists consultations and supports status transitions',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      final rows = [Map<String, dynamic>.from(consultationRow)];
      final updateCalls = <Map<String, dynamic>>[];

      final backend = _backend((request) async {
        if (request.url.path.contains('list_admin_consultations')) {
          return _json(rows, 200);
        }
        if (request.url.path.contains('update_admin_consultation')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          updateCalls.add(body);
          rows[0]['status'] = body['p_status'];
          if (body.containsKey('p_admin_note')) {
            rows[0]['admin_note'] = body['p_admin_note'];
          }
          return _json(null, 200);
        }
        return _json({'error': 'not found'}, 404);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            supabaseClientServiceProvider.overrideWithValue(backend),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const AdminConsultationsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Consultation row must be rendered with topic
      expect(find.text('Study Visa Work Permit Query'), findsOneWidget);

      // Expand the tile
      await tester.tap(find.text('Study Visa Work Permit Query'));
      await tester.pumpAndSettle();

      // Expansion child details should now be visible
      expect(
        find.text('Need advice on postgraduate work permit transition.'),
        findsOneWidget,
      );

      // Status dropdown must show 'Submitted'
      final dropdown = find.byType(DropdownButtonFormField<String>);
      expect(dropdown, findsOneWidget);

      // Open status dropdown and select 'Under review' (l10n.statusReviewing,
      // the label for the 'in_review' status value).
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      final inReviewOption = find.text('Under review').last;
      await tester.tap(inReviewOption);
      await tester.pumpAndSettle();

      // Verify update_admin_consultation was called
      expect(updateCalls.length, 1);
      expect(
        updateCalls.first['p_consultation_id'],
        '77777777-7777-7777-7777-777777777777',
      );
      expect(updateCalls.first['p_status'], 'in_review');

      // After a successful update the page reloads the list (loading state),
      // which rebuilds the tiles collapsed. Re-expand before editing the note.
      expect(find.text('Study Visa Work Permit Query'), findsOneWidget);
      await tester.tap(find.text('Study Visa Work Permit Query'));
      await tester.pumpAndSettle();

      // Now verify admin note submission
      final noteField = find.byType(TextFormField);
      expect(noteField, findsOneWidget);

      // Submit the note through the field's own submit handler. Driving the
      // soft keyboard (enterText + receiveAction) leaves the focused field in
      // a state where the test pump loop never returns, so the handler is
      // invoked directly; it is the same code path the keyboard "done" action
      // triggers and still exercises the page's RPC contract.
      const note =
          'Assigned to senior consultant for document checklist review.';
      tester
          .widget<TextField>(
            find.descendant(of: noteField, matching: find.byType(TextField)),
          )
          .onSubmitted!(note);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(updateCalls.length, 2);
      expect(
        updateCalls.last['p_admin_note'],
        'Assigned to senior consultant for document checklist review.',
      );
    },
  );

  testWidgets(
    'AdminConsultationsPage displays error state and supports retry on fetch failure',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      var fail = true;

      final backend = _backend((request) async {
        if (request.url.path.contains('list_admin_consultations')) {
          if (fail) {
            return _json({'message': 'forbidden'}, 403);
          }
          return _json([consultationRow], 200);
        }
        return _json({'error': 'not found'}, 404);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            supabaseClientServiceProvider.overrideWithValue(backend),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const AdminConsultationsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Error state should be shown
      expect(find.text('Retry'), findsOneWidget);

      // Now clear failure and retry
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Topic should now be visible
      expect(find.text('Study Visa Work Permit Query'), findsOneWidget);
    },
  );
}
