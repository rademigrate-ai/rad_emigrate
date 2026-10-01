import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/profile/domain/entities/user_profile.dart';

void main() {
  test('profile save fields survive json round-trip for repository boundary', () {
    final profile = UserProfile(
      id: 'u1',
      firstName: 'Sara',
      lastName: 'Rad',
      email: 'sara@example.com',
      nationality: 'IR',
    );
    final restored = UserProfile.fromJson(profile.toJson());
    expect(restored.firstName, 'Sara');
    expect(restored.nationality, 'IR');
    expect(restored.fullName, 'Sara Rad');
  });
}
