import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/theme_controller.dart';

const _recoveryUserIdKey = 'rad_password_recovery_user_id';

/// Records that the current Supabase session originated from PASSWORD_RECOVERY.
///
/// The marker is never an authorization credential: it is accepted only when
/// it matches a live Supabase session for the same user. Its sole purpose is
/// to preserve the recovery-flow UI gate across a browser refresh.
class PasswordRecoveryState {
  const PasswordRecoveryState(this.userId);

  final String? userId;

  bool isReadyFor(String? activeUserId) =>
      userId != null && activeUserId != null && userId == activeUserId;
}

class PasswordRecoveryController extends StateNotifier<PasswordRecoveryState> {
  PasswordRecoveryController(SharedPreferences preferences)
    : _preferences = preferences,
      super(PasswordRecoveryState(preferences.getString(_recoveryUserIdKey)));

  final SharedPreferences _preferences;

  Future<void> markRecovery(String userId) async {
    if (userId.isEmpty) {
      await clear();
      return;
    }
    state = PasswordRecoveryState(userId);
    await _preferences.setString(_recoveryUserIdKey, userId);
  }

  /// Drops stale recovery state when it does not belong to the active session.
  Future<void> reconcileActiveSession(String? activeUserId) async {
    if (!state.isReadyFor(activeUserId)) await clear();
  }

  Future<void> clear() async {
    state = const PasswordRecoveryState(null);
    await _preferences.remove(_recoveryUserIdKey);
  }
}

final passwordRecoveryControllerProvider =
    StateNotifierProvider<PasswordRecoveryController, PasswordRecoveryState>(
      (ref) => PasswordRecoveryController(ref.watch(sharedPreferencesProvider)),
    );
