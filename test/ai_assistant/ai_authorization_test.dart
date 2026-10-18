import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/ai_assistant/domain/ai_authorization.dart';

void main() {
  const auth = AiAuthorization();

  group('user chat', () {
    test('authenticated user allowed', () {
      final d = auth.authorize(
        surface: AiSurface.userChat,
        session: const AiSessionContext(
          callerRole: AiCallerRole.user,
          callerUserId: 'u1',
        ),
      );
      expect(d.allowed, isTrue);
    });

    test('anonymous requires guest hash bounds', () {
      final bad = auth.authorize(
        surface: AiSurface.userChat,
        session: const AiSessionContext(
          callerRole: AiCallerRole.anonymous,
          callerUserId: null,
          guestKeyHash: 'short',
        ),
      );
      expect(bad.allowed, isFalse);

      final good = auth.authorize(
        surface: AiSurface.userChat,
        session: AiSessionContext(
          callerRole: AiCallerRole.anonymous,
          callerUserId: null,
          guestKeyHash: List.filled(40, 'a').join(),
        ),
      );
      expect(good.allowed, isTrue);
      expect(good.reason, 'guest_path');
    });

    test('service cannot impersonate user chat', () {
      final d = auth.authorize(
        surface: AiSurface.userChat,
        session: const AiSessionContext(
          callerRole: AiCallerRole.service,
          callerUserId: null,
        ),
      );
      expect(d.allowed, isFalse);
    });
  });

  group('admin surfaces', () {
    test('user denied admin config', () {
      final d = auth.authorize(
        surface: AiSurface.adminConfig,
        session: const AiSessionContext(
          callerRole: AiCallerRole.user,
          callerUserId: 'u1',
        ),
      );
      expect(d.reason, 'admin_role_required');
    });

    test('admin allowed', () {
      final d = auth.authorize(
        surface: AiSurface.adminProbe,
        session: const AiSessionContext(
          callerRole: AiCallerRole.admin,
          callerUserId: 'admin-1',
        ),
      );
      expect(d.allowed, isTrue);
    });
  });

  group('ownership', () {
    test('cross-account denied', () {
      final d = auth.authorizeOwnedResource(
        session: const AiSessionContext(
          callerRole: AiCallerRole.user,
          callerUserId: 'u1',
        ),
        resourceOwnerId: 'u2',
      );
      expect(d.reason, 'cross_account_forbidden');
    });

    test('owner allowed', () {
      final d = auth.authorizeOwnedResource(
        session: const AiSessionContext(
          callerRole: AiCallerRole.user,
          callerUserId: 'u1',
        ),
        resourceOwnerId: 'u1',
      );
      expect(d.allowed, isTrue);
    });

    test('admin cannot read other user chat via this gate', () {
      final d = auth.authorizeOwnedResource(
        session: const AiSessionContext(
          callerRole: AiCallerRole.admin,
          callerUserId: 'admin-1',
        ),
        resourceOwnerId: 'u2',
      );
      expect(d.reason, 'admin_cross_user_chat_forbidden');
    });
  });
}
