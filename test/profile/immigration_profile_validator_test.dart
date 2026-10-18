import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/profile/domain/entities/profile_entity.dart';
import 'package:rad_emigrate/features/profile/domain/immigration_profile_validator.dart';

void main() {
  group('ImmigrationProfile field lifecycle', () {
    test('empty profile is all notProvided', () {
      const profile = ImmigrationProfile();
      final statuses = ImmigrationProfileValidator.fieldStatuses(profile);
      for (final status in statuses.values) {
        expect(status, ProfileFieldStatus.notProvided);
      }
      expect(ImmigrationProfileValidator.completenessPercent(profile), 0);
      expect(
        ImmigrationProfileValidator.isStructurallyComplete(profile),
        isFalse,
      );
    });

    test('markUnknown sets status and clears value', () {
      final profile = const ImmigrationProfile(fullName: 'Ada')
          .markUnknown(ImmigrationProfileField.fullName);
      expect(profile.fullName, isEmpty);
      expect(
        profile.unknownFields.contains(ImmigrationProfileField.fullName),
        isTrue,
      );
      expect(
        ImmigrationProfileValidator.statusOf(
          profile,
          ImmigrationProfileField.fullName,
        ),
        ProfileFieldStatus.unknown,
      );
    });

    test('provide clears unknown and sets value', () {
      final unknown = const ImmigrationProfile().markUnknown(
        ImmigrationProfileField.email,
      );
      final provided = unknown.provide(
        ImmigrationProfileField.email,
        value: 'ada@example.com',
      );
      expect(provided.email, 'ada@example.com');
      expect(
        provided.unknownFields.contains(ImmigrationProfileField.email),
        isFalse,
      );
      expect(
        ImmigrationProfileValidator.statusOf(
          provided,
          ImmigrationProfileField.email,
        ),
        ProfileFieldStatus.provided,
      );
    });

    test('toJson / fromJson round-trip preserves unknownFields', () {
      final original = const ImmigrationProfile(
        fullName: 'Ada Lovelace',
        languages: ['en', 'fa'],
      ).markUnknown(ImmigrationProfileField.maritalStatus);
      final restored = ImmigrationProfile.fromJson(original.toJson());
      expect(restored, original);
      expect(
        restored.unknownFields.contains(ImmigrationProfileField.maritalStatus),
        isTrue,
      );
    });
  });

  group('ImmigrationProfileValidator structural checks', () {
    test('valid email and phone are provided', () {
      const profile = ImmigrationProfile(
        email: 'user@radvisa.com',
        phone: '+98 912 345 6789',
      );
      expect(
        ImmigrationProfileValidator.statusOf(
          profile,
          ImmigrationProfileField.email,
        ),
        ProfileFieldStatus.provided,
      );
      expect(
        ImmigrationProfileValidator.statusOf(
          profile,
          ImmigrationProfileField.phone,
        ),
        ProfileFieldStatus.provided,
      );
    });

    test('invalid email and short phone are invalid', () {
      const profile = ImmigrationProfile(email: 'not-an-email', phone: '123');
      expect(
        ImmigrationProfileValidator.statusOf(
          profile,
          ImmigrationProfileField.email,
        ),
        ProfileFieldStatus.invalid,
      );
      expect(
        ImmigrationProfileValidator.statusOf(
          profile,
          ImmigrationProfileField.phone,
        ),
        ProfileFieldStatus.invalid,
      );
      final result = ImmigrationProfileValidator.validate(profile);
      expect(result.hasErrors, isTrue);
      expect(
        result.invalidFields,
        containsAll([
          ImmigrationProfileField.email,
          ImmigrationProfileField.phone,
        ]),
      );
    });

    test('languages empty is notProvided; non-empty is provided', () {
      const empty = ImmigrationProfile(languages: []);
      expect(
        ImmigrationProfileValidator.statusOf(
          empty,
          ImmigrationProfileField.languages,
        ),
        ProfileFieldStatus.notProvided,
      );
      const filled = ImmigrationProfile(languages: ['Persian', 'English']);
      expect(
        ImmigrationProfileValidator.statusOf(
          filled,
          ImmigrationProfileField.languages,
        ),
        ProfileFieldStatus.provided,
      );
    });

    test('completeness counts provided and unknown equally', () {
      // 9 scored fields. Mark 3 unknown, provide 3 valid, leave 3 empty.
      var profile = const ImmigrationProfile(
        fullName: 'Ada Lovelace',
        email: 'ada@example.com',
        nationality: 'GB',
      );
      profile = profile.markUnknown(ImmigrationProfileField.phone);
      profile = profile.markUnknown(ImmigrationProfileField.education);
      profile = profile.markUnknown(ImmigrationProfileField.workExperience);

      // 3 provided + 3 unknown = 6/9 ≈ 67%
      expect(ImmigrationProfileValidator.completenessPercent(profile), 67);
      expect(ImmigrationProfileValidator.incompleteFields(profile).length, 3);
      expect(
        ImmigrationProfileValidator.isStructurallyComplete(profile),
        isFalse,
      );
    });

    test('fully provided profile is structurally complete', () {
      const profile = ImmigrationProfile(
        fullName: 'Ada Lovelace',
        email: 'ada@example.com',
        phone: '+441234567890',
        nationality: 'GB',
        education: 'Mathematics',
        workExperience: 'Analytical engine',
        languages: ['en'],
        destinationPreference: 'Canada',
        maritalStatus: 'single',
      );
      final result = ImmigrationProfileValidator.validate(profile);
      expect(result.isStructurallyComplete, isTrue);
      expect(result.completenessPercent, 100);
      expect(result.invalidFields, isEmpty);
      expect(result.missingFields, isEmpty);
    });

    test('whitespace-only strings count as notProvided', () {
      const profile = ImmigrationProfile(fullName: '   ', nationality: '\t');
      expect(
        ImmigrationProfileValidator.statusOf(
          profile,
          ImmigrationProfileField.fullName,
        ),
        ProfileFieldStatus.notProvided,
      );
      expect(
        ImmigrationProfileValidator.statusOf(
          profile,
          ImmigrationProfileField.nationality,
        ),
        ProfileFieldStatus.notProvided,
      );
    });
  });
}
