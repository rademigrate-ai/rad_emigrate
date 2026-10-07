import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/profile/domain/entities/user_profile.dart';
import 'package:rad_emigrate/features/profile/domain/repositories/profile_repository.dart';
import 'package:rad_emigrate/features/profile/presentation/providers/profile_controller.dart';

const session = UserSession(
  userId: 'user-one',
  token: 'test-only-session',
  authenticated: true,
  fullName: 'RAD Test',
);

class AuthStub implements AuthRepository {
  final completion = Completer<UserSession>();
  @override
  Future<UserSession> completeProfile({
    required String fullName,
    String? nationality,
  }) => completion.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ProfileStub implements ProfileRepository {
  bool fail = false;
  @override
  Future<UserProfile?> getProfile(String userId) async =>
      UserProfile(id: userId, phone: '+12025550100');
  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    if (fail) throw StateError('ordinary profile failure');
    return profile;
  }
}

void main() {
  test('profile metadata remains authenticated while saving and after ordinary failure', () async {
    final repository = AuthStub();
    final auth = AuthController(repository)..applySession(session);
    addTearDown(auth.dispose);
    final save = auth.completeProfile(fullName: 'Updated Name');
    expect(auth.state.valueOrNull?.isAuthenticated, isTrue);
    repository.completion.completeError(StateError('network failure'));
    await expectLater(save, throwsStateError);
    expect(auth.state.valueOrNull?.isAuthenticated, isTrue);
    expect(auth.state.valueOrNull?.userId, 'user-one');
  });
  test('phone persistence and ordinary failure preserve global auth', () async {
    final repository = ProfileStub();
    final auth = AuthController(AuthStub())..applySession(session);
    final profile = ProfileController(repository, session);
    addTearDown(profile.dispose);
    addTearDown(auth.dispose);
    await profile.load();
    await profile.save(UserProfile(id: 'user-one', phone: '+12025550101'));
    expect(profile.state.valueOrNull?.phone, '+12025550101');
    expect(auth.state.valueOrNull?.isAuthenticated, isTrue);
    repository.fail = true;
    await expectLater(
      profile.save(UserProfile(id: 'user-one', phone: '+12025550102')),
      throwsStateError,
    );
    expect(profile.state.valueOrNull?.phone, '+12025550101');
    expect(auth.state.valueOrNull?.isAuthenticated, isTrue);
  });
}
