import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rad_emigrate/core/services/ai/ai_request.dart';
import 'package:rad_emigrate/core/services/ai/supabase_ai_service.dart';

import '../support/mock_supabase_service.dart';
import '../support/rad_contract_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final status in [200, 503]) {
    test(
      'AI service suppresses late owner reply/error after logout ($status)',
      () async {
        final pending = Completer<http.Response>();
        final started = Completer<void>();
        final service = await mockSupabaseService((request) {
          if (request.url.path.contains('/functions/')) {
            started.complete();
            return pending.future;
          }
          return Future.value(rpcJson({}));
        });
        final result = SupabaseAiService(service).complete(
          const AiRequest(
            prompt: 'Synthetic private question',
            locale: 'en',
            conversationId: fixtureId,
          ),
        );
        await started.future;
        await service.client.auth.signOut(scope: SignOutScope.local);
        pending.complete(
          rpcJson(
            status == 200 ? validAiEnvelope() : {'code': 'private_owner_error'},
            status,
          ),
        );
        final response = await result;
        expect(response.errorCode, 'session_changed');
        expect(response.uncertain, true);
        expect(response.conversationId, isNull);
        expect(response.sources, isEmpty);
        expect(response.text, isNot(contains('SYNTHETIC')));
      },
    );
  }
}
