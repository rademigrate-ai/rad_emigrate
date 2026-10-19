/// Authorization boundaries for user and admin AI surfaces.
///
/// Pure domain rules. Does not call providers or Supabase.
/// Cross-account leakage and role escalation are rejected here so
/// clients and Edge handlers share one deterministic contract.
library;

enum AiSurface { userChat, adminConfig, adminProbe, adminModelSync }

enum AiCallerRole { anonymous, user, admin, superAdmin, service }

class AiAuthDecision {
  const AiAuthDecision.allow({this.reason = 'allowed'}) : allowed = true;

  const AiAuthDecision.deny(this.reason) : allowed = false;

  final bool allowed;
  final String reason;
}

class AiSessionContext {
  const AiSessionContext({
    required this.callerRole,
    required this.callerUserId,
    this.targetUserId,
    this.guestKeyHash,
  });

  final AiCallerRole callerRole;
  final String? callerUserId;
  final String? targetUserId;
  final String? guestKeyHash;
}

/// Deterministic authorization for AI surfaces.
class AiAuthorization {
  const AiAuthorization();

  AiAuthDecision authorize({
    required AiSurface surface,
    required AiSessionContext session,
  }) {
    switch (surface) {
      case AiSurface.userChat:
        return _authorizeUserChat(session);
      case AiSurface.adminConfig:
      case AiSurface.adminProbe:
      case AiSurface.adminModelSync:
        return _authorizeAdmin(session);
    }
  }

  /// Prevents reading another user's conversation or quota metadata.
  AiAuthDecision authorizeOwnedResource({
    required AiSessionContext session,
    required String resourceOwnerId,
  }) {
    if (session.callerRole == AiCallerRole.service) {
      return const AiAuthDecision.allow(reason: 'service');
    }
    if (session.callerRole == AiCallerRole.superAdmin ||
        session.callerRole == AiCallerRole.admin) {
      // Admin may inspect operational metadata, not raw private chat history
      // across accounts through this domain gate. Cross-user chat is denied.
      return const AiAuthDecision.deny('admin_cross_user_chat_forbidden');
    }
    if (session.callerUserId == null || session.callerUserId!.isEmpty) {
      return const AiAuthDecision.deny('authentication_required');
    }
    if (session.callerUserId != resourceOwnerId) {
      return const AiAuthDecision.deny('cross_account_forbidden');
    }
    return const AiAuthDecision.allow();
  }

  AiAuthDecision _authorizeUserChat(AiSessionContext session) {
    switch (session.callerRole) {
      case AiCallerRole.user:
      case AiCallerRole.admin:
      case AiCallerRole.superAdmin:
        if (session.callerUserId == null || session.callerUserId!.isEmpty) {
          return const AiAuthDecision.deny('authentication_required');
        }
        return const AiAuthDecision.allow();
      case AiCallerRole.anonymous:
        final hash = session.guestKeyHash;
        if (hash == null || hash.length < 32 || hash.length > 128) {
          return const AiAuthDecision.deny('guest_identity_required');
        }
        return const AiAuthDecision.allow(reason: 'guest_path');
      case AiCallerRole.service:
        return const AiAuthDecision.deny(
          'service_cannot_impersonate_user_chat',
        );
    }
  }

  AiAuthDecision _authorizeAdmin(AiSessionContext session) {
    switch (session.callerRole) {
      case AiCallerRole.admin:
      case AiCallerRole.superAdmin:
        return const AiAuthDecision.allow();
      case AiCallerRole.service:
        return const AiAuthDecision.allow(reason: 'service');
      case AiCallerRole.user:
      case AiCallerRole.anonymous:
        return const AiAuthDecision.deny('admin_role_required');
    }
  }
}
