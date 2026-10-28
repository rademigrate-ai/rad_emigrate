import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/ai_assistant/domain/ai_profile_contract.dart';
import 'package:rad_emigrate/features/ai_assistant/domain/entities/ai_user_profile.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/providers/ai_user_profile_provider.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory mock for flutter_secure_storage method channel.
final Map<String, String> _secureStore = <String, String>{};

void _installSecureStorageMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          switch (call.method) {
            case 'read':
              final key = (call.arguments as Map)['key'] as String?;
              return key == null ? null : _secureStore[key];
            case 'write':
              final args = call.arguments as Map;
              final key = args['key'] as String?;
              final value = args['value'] as String?;
              if (key != null && value != null) _secureStore[key] = value;
              return null;
            case 'delete':
              final key = (call.arguments as Map)['key'] as String?;
              if (key != null) _secureStore.remove(key);
              return null;
            case 'deleteAll':
              _secureStore.clear();
              return null;
            case 'readAll':
              return Map<String, String>.from(_secureStore);
            case 'containsKey':
              final key = (call.arguments as Map)['key'] as String?;
              return key != null && _secureStore.containsKey(key);
            default:
              return null;
          }
        },
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _secureStore.clear();
    SharedPreferences.setMockInitialValues({});
    _installSecureStorageMock();
  });

  group('AiImmigrationProfile Contract & Formatting', () {
    test(
      'toAiContext returns empty map when consent/personalization is disabled',
      () {
        const profile = AiImmigrationProfile(
          education: 'کارشناسی نرم‌افزار',
          workExperienceYears: 5,
          languageScore: 'IELTS 7.5',
          targetCountry: 'آلمان',
          estimatedBudget: '20,000 EUR',
          enableAiPersonalization: false,
        );

        final context = profile.toAiContext();
        expect(context, isEmpty);
      },
    );

    test(
      'toAiContext maps only non-empty fields matching kAiProfileContextKeys',
      () {
        const profile = AiImmigrationProfile(
          education: 'Master of CS',
          workExperienceYears: 4,
          languageScore: 'IELTS 7.5',
          targetCountry: 'Germany',
          estimatedBudget: '25,000 EUR',
          enableAiPersonalization: true,
        );

        final context = profile.toAiContext();
        expect(context['education'], 'Master of CS');
        expect(context['experience_years'], '4');
        expect(context['language'], 'IELTS 7.5');
        expect(context['target_country'], 'Germany');
        expect(context['budget'], '25,000 EUR');

        for (final key in context.keys) {
          expect(
            kAiProfileContextKeys.contains(key),
            isTrue,
            reason: 'Key $key must be allowed in kAiProfileContextKeys',
          );
        }
      },
    );

    test(
      'antigravityProfileToServerParams converts profile to server parameters',
      () {
        final params = antigravityProfileToServerParams(
          education: 'PhD Bio',
          workExperienceYears: 6,
          languageScore: 'TOEFL 105',
          targetCountry: 'Canada',
          estimatedBudget: '40,000 CAD',
          consent: true,
        );

        expect(params['p_education'], 'PhD Bio');
        expect(params['p_work_experience'], '6 years');
        expect(params['p_language_level'], 'TOEFL 105');
        expect(params['p_preferred_destinations'], ['Canada']);
        expect(params['p_budget_range'], '40,000 CAD');
        expect(params['p_consent'], isTrue);
      },
    );

    test('serverProfileToAiContext converts database row to orchestrator context bag', () {
      final row = {
        'education': 'Bachelor',
        'field_of_study': 'Computer Engineering',
        'work_experience': '5 years',
        'language_level': 'C1',
        'budget_range': '30000 USD',
        'preferred_destinations': ['Germany', 'Netherlands'],
        'interested_pathways': ['EU Blue Card', 'Job Seeker'],
        'notes': 'Looking for immediate relocation',
      };

      final context = serverProfileToAiContext(row);
      expect(context['education'], 'Bachelor');
      expect(context['field_of_study'], 'Computer Engineering');
      expect(context['work_experience'], '5 years');
      expect(context['language_level'], 'C1');
      expect(context['budget_range'], '30000 USD');
      expect(context['target_country'], 'Germany');
      expect(context['preferred_destinations'], 'Germany, Netherlands');
      expect(context['interested_pathways'], 'EU Blue Card, Job Seeker');
      expect(context['notes'], 'Looking for immediate relocation');
    });
  });

  group('AiUserProfileNotifier State & Secure Persistence', () {
    test(
      'updates and clears via encrypted storage; purges legacy plaintext',
      () async {
        // Seed legacy plaintext (must be removed after secure write/load).
        SharedPreferences.setMockInitialValues({
          'ai_profile_user123_education': 'legacy',
          'ai_profile_user123_experience': 1,
          'ai_profile_user123_language': 'A1',
          'ai_profile_user123_country': 'X',
          'ai_profile_user123_budget': '0',
          'ai_profile_user123_enabled': true,
        });

        final container = ProviderContainer(
          overrides: [
            authenticatedUserIdProvider.overrideWith((ref) => 'user123'),
          ],
        );
        addTearDown(container.dispose);

        container.read(aiUserProfileProvider);
        await Future<void>.delayed(const Duration(milliseconds: 80));

        // Legacy plaintext must not be treated as source of truth after purge path.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('ai_profile_user123_education'), isNull);

        await container
            .read(aiUserProfileProvider.notifier)
            .updateProfile(
              const AiImmigrationProfile(
                education: 'کارشناسی ارشد',
                workExperienceYears: 3,
                languageScore: 'B2 Goethe',
                targetCountry: 'آلمان',
                estimatedBudget: '15,000 EUR',
                enableAiPersonalization: true,
              ),
            );

        final profile = container.read(aiUserProfileProvider);
        expect(profile.education, 'کارشناسی ارشد');
        expect(profile.workExperienceYears, 3);
        expect(profile.languageScore, 'B2 Goethe');

        expect(
          _secureStore['ai_profile_secure_user123_education'],
          'کارشناسی ارشد',
        );
        expect(_secureStore['ai_profile_secure_user123_experience'], '3');
        expect(_secureStore['ai_profile_secure_user123_language'], 'B2 Goethe');

        await container
            .read(aiUserProfileProvider.notifier)
            .updateProfile(
              profile.copyWith(
                workExperienceYears: 4,
                languageScore: 'C1 Goethe',
              ),
            );

        final updated = container.read(aiUserProfileProvider);
        expect(updated.workExperienceYears, 4);
        expect(updated.languageScore, 'C1 Goethe');
        expect(_secureStore['ai_profile_secure_user123_experience'], '4');
        expect(_secureStore['ai_profile_secure_user123_language'], 'C1 Goethe');

        await container.read(aiUserProfileProvider.notifier).clearProfile();
        final cleared = container.read(aiUserProfileProvider);
        expect(cleared.hasContent, isFalse);
        expect(
          _secureStore.containsKey('ai_profile_secure_user123_education'),
          isFalse,
        );
        expect(prefs.getString('ai_profile_user123_education'), isNull);
      },
    );

    test('resets when user is unauthenticated', () async {
      final container = ProviderContainer(
        overrides: [authenticatedUserIdProvider.overrideWith((ref) => null)],
      );
      addTearDown(container.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final profile = container.read(aiUserProfileProvider);
      expect(profile.hasContent, isFalse);
    });
  });
}
