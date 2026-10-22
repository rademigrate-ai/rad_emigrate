import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/routing/auth_redirect.dart';

void main() {
  group('AppShell & Route Alignment Tests', () {
    test(
      'auth_redirect recognizes /profile/cases and nested paths as protected',
      () {
        expect(isProtectedPath('/profile/cases'), isTrue);
        expect(isProtectedPath('/profile/cases/app-123'), isTrue);
        expect(isProtectedPath('/applications'), isTrue);
        expect(isProtectedPath('/admin/cms'), isTrue);
        expect(isProtectedPath('/admin/sources'), isTrue);
      },
    );

    test('auth_redirect recognizes public in-app routes', () {
      expect(isProtectedPath('/dashboard'), isFalse);
      expect(isProtectedPath('/visa'), isFalse);
      expect(isProtectedPath('/visa/search'), isFalse);
      expect(isProtectedPath('/feed'), isFalse);
      expect(isProtectedPath('/profile'), isFalse);
      expect(isProtectedPath('/ai-assistant'), isFalse);
      expect(isProtectedPath('/booking'), isFalse);
      expect(isProtectedPath('/interview-scheduling'), isFalse);
      expect(isProtectedPath('/calculator/cost'), isFalse);
      expect(isProtectedPath('/compare/pathways'), isFalse);
      expect(isProtectedPath('/compare/universities'), isFalse);
    });
  });
}
