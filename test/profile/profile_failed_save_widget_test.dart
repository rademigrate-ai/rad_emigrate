import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/profile/domain/entities/user_profile.dart';
import 'package:rad_emigrate/features/profile/domain/repositories/profile_repository.dart';
import 'package:rad_emigrate/features/profile/presentation/pages/profile_page.dart';
import 'package:rad_emigrate/features/profile/presentation/providers/profile_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _Auth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profiles implements ProfileRepository {
  bool fail = true;
  UserProfile profile = UserProfile(
    id: 'user',
    firstName: 'RAD',
    lastName: 'Test',
    phone: '+12025550100',
  );
  @override
  Future<UserProfile?> getProfile(String userId) async => profile;
  @override
  Future<UserProfile> updateProfile(UserProfile value) async {
    if (fail) throw StateError('ordinary save failure');
    return profile = value;
  }
}

void main() {
  testWidgets(
    'ordinary phone-save failure retains form and permits retry while authenticated',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final profiles = _Profiles();
      final auth = AuthController(_Auth())
        ..applySession(
          const UserSession(
            userId: 'user',
            token: 'fixture-only-token',
            authenticated: true,
            fullName: 'RAD Test',
          ),
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            profileRepositoryProvider.overrideWithValue(profiles),
            authControllerProvider.overrideWith((ref) => auth),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      final phone = find.byType(TextFormField).at(3);
      await tester.enterText(phone, '+12025550101');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(auth.state.valueOrNull?.isAuthenticated, isTrue);
      expect(find.byType(TextFormField), findsNWidgets(5));
      expect(find.text('+12025550101'), findsOneWidget);
      profiles.fail = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(profiles.profile.phone, '+12025550101');
      expect(auth.state.valueOrNull?.isAuthenticated, isTrue);
      expect(find.byType(TextFormField), findsNothing);
    },
  );
}
