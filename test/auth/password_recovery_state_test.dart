import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/password_recovery_controller.dart';

void main() {
  test('recovery state requires a matching non-null active user', () {
    const state = PasswordRecoveryState('recovery-user');

    expect(state.isReadyFor('recovery-user'), isTrue);
    expect(state.isReadyFor('another-user'), isFalse);
    expect(state.isReadyFor(null), isFalse);
  });
}
