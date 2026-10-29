import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/ai_assistant/domain/ai_authorization.dart';

void main() {
  const auth = AiAuthorization();

  group('Plan5 AI authorization boundaries', () {
    test('anonymous cannot access admin config', () {
      final decision = auth.authorize(
        surface: AiSurface.adminConfig,
        session: const AiSessionContext(
          callerRole: AiCallerRole.anonymous,
          callerUserId: null,
        ),
      );
      expect(decision.allowed, isFalse);
    });

    test('user cannot access admin model sync', () {
      final decision = auth.authorize(
        surface: AiSurface.adminModelSync,
        session: const AiSessionContext(
          callerRole: AiCallerRole.user,
          callerUserId: 'user-a',
        ),
      );
      expect(decision.allowed, isFalse);
    });

    test('user cannot read another user resource', () {
      final decision = auth.authorizeOwnedResource(
        session: const AiSessionContext(
          callerRole: AiCallerRole.user,
          callerUserId: 'user-a',
        ),
        resourceOwnerId: 'user-b',
      );
      expect(decision.allowed, isFalse);
      expect(decision.reason, 'cross_account_forbidden');
    });

    test('owner can read own resource', () {
      final decision = auth.authorizeOwnedResource(
        session: const AiSessionContext(
          callerRole: AiCallerRole.user,
          callerUserId: 'user-a',
        ),
        resourceOwnerId: 'user-a',
      );
      expect(decision.allowed, isTrue);
    });

    test('admin cannot use domain gate for cross-user chat history', () {
      final decision = auth.authorizeOwnedResource(
        session: const AiSessionContext(
          callerRole: AiCallerRole.admin,
          callerUserId: 'admin-1',
        ),
        resourceOwnerId: 'user-b',
      );
      expect(decision.allowed, isFalse);
      expect(decision.reason, 'admin_cross_user_chat_forbidden');
    });
  });
}
