import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/profile/domain/entities/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('fromJson / toJson round-trip', () {
      final profile = UserProfile(
        id: 'u1',
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: 'ada@example.com',
        phone: '+1000000',
        nationality: 'GB',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);
      expect(restored.id, profile.id);
      expect(restored.firstName, profile.firstName);
      expect(restored.lastName, profile.lastName);
      expect(restored.email, profile.email);
      expect(restored.fullName, 'Ada Lovelace');
      expect(restored, profile);
    });

    test('copyWith overrides fields', () {
      const original = UserProfile(id: 'u1', firstName: 'Ada');
      final updated = original.copyWith(lastName: 'Lovelace');
      expect(updated.firstName, 'Ada');
      expect(updated.lastName, 'Lovelace');
    });

    test('equality', () {
      const a = UserProfile(id: 'u1', email: 'a@b.c');
      const b = UserProfile(id: 'u1', email: 'a@b.c');
      const c = UserProfile(id: 'u2', email: 'a@b.c');
      expect(a, b);
      expect(a == c, isFalse);
    });
  });
}
