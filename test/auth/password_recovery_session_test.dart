import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/password_recovery_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'recovery marker survives refresh only for the matching session user',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final controller = PasswordRecoveryController(preferences);

      expect(controller.state.isReadyFor('user-a'), isFalse);

      await controller.markRecovery('user-a');
      expect(controller.state.isReadyFor('user-a'), isTrue);

      final rehydrated = PasswordRecoveryController(preferences);
      expect(rehydrated.state.isReadyFor('user-a'), isTrue);

      await rehydrated.reconcileActiveSession('user-b');
      expect(rehydrated.state.isReadyFor('user-a'), isFalse);

      controller.dispose();
      rehydrated.dispose();
    },
  );

  test('clearing recovery state removes the persisted UI gate', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = PasswordRecoveryController(preferences);

    await controller.markRecovery('user-a');
    await controller.clear();

    expect(controller.state.isReadyFor('user-a'), isFalse);
    final rehydrated = PasswordRecoveryController(preferences);
    expect(rehydrated.state.isReadyFor('user-a'), isFalse);
    controller.dispose();
    rehydrated.dispose();
  });
}
