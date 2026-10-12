import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/routing/auth_redirect.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';

/// Journey 5: Consultation route + form contracts.
/// Pumping ConsultationPage requires initialized Supabase (initState _loadMine).
void main() {
  test(
    'UJ05 unauthenticated deep link to /consultation redirects to login',
    () {
      final result = authRedirect(
        uri: Uri.parse('/consultation'),
        isRestoring: false,
        isAuthenticated: false,
        profileComplete: false,
      );
      expect(result, isNotNull);
      final login = Uri.parse(result!);
      expect(login.path, '/login');
      expect(login.queryParameters['from'], '/consultation');
    },
  );

  test('UJ05b consultation is a known protected destination', () {
    expect(restoredProtectedDestination('/consultation'), '/consultation');
  });

  test(
    'UJ05c consultation page source enforces auth gate and required fields',
    () {
      final src = File(
        'lib/features/consultation/presentation/pages/consultation_page.dart',
      ).readAsStringSync();
      expect(src, contains("session?.authenticated != true"));
      expect(src, contains("context.go('/login?from=%2Fconsultation')"));
      expect(src, contains('consultationFieldsRequired'));
      expect(src, contains("'submit_consultation_request'"));
      expect(src, isNot(contains("from('consultation_requests').insert")));
      expect(src, contains('initialTopic'));
    },
  );

  test('UJ05d UserSession defaults to unauthenticated', () {
    const session = UserSession();
    expect(session.authenticated, isFalse);
    expect(session.isAuthenticated, isFalse);
  });
}
