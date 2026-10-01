import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_controller.dart';
import 'session_manager.dart';
import 'session_state.dart';

/// SessionManager wired to the auth repository.
final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager(ref.watch(authRepositoryProvider));
});

/// Live session state derived from [AuthController] for UI and routing.
final sessionStateProvider = Provider<SessionState>((ref) {
  final auth = ref.watch(authControllerProvider);
  final session = auth.valueOrNull;
  if (session != null && session.isAuthenticated) {
    return SessionState(
      status: SessionStatus.authenticated,
      session: session,
    );
  }
  if (auth.isLoading) {
    return SessionState.unknown;
  }
  return SessionState.unauthenticated;
});
