import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/providers/ai_prompt_draft_provider.dart';
import 'package:rad_emigrate/features/consultation/presentation/providers/consultation_draft_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'AI draft hydrates from storage and is consumed only explicitly',
    () async {
      SharedPreferences.setMockInitialValues({
        'rad_ai_pending_prompt::guest': 'Saved visa question',
        'rad_ai_pending_context::guest': 'Canada',
      });
      final draft = AiPromptDraftNotifier();
      await draft.ready;
      expect(draft.state.prompt, 'Saved visa question');
      expect(draft.state.contextLabel, 'Canada');
      expect(await draft.consumePrompt(), 'Saved visa question');
      expect(draft.state.hasContent, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('rad_ai_pending_prompt::guest'), isNull);
      draft.dispose();
    },
  );

  test('Consultation draft hydrates without pending submission', () async {
    SharedPreferences.setMockInitialValues({
      'rad_consultation_draft_topic::guest': 'Study',
      'rad_consultation_draft_message::guest': 'Please advise',
    });
    final draft = ConsultationDraftNotifier();
    await draft.ready;
    expect(draft.state.topic, 'Study');
    expect(draft.state.message, 'Please advise');
    await draft.clearDraft();
    expect(draft.state.isEmpty, true);
    draft.dispose();
  });

  test(
    'AI draft handles Persian and English Unicode and empty string clearing',
    () async {
      SharedPreferences.setMockInitialValues({});
      final draft = AiPromptDraftNotifier();
      await draft.ready;

      // Save Persian + English prompt
      await draft.savePrompt(
        'سلام! شرایط ویزای استارتاپ کانادا چیست؟\nWhat are the language criteria? 🇨🇦',
        'Canada Startup Visa',
      );
      expect(draft.state.hasContent, true);
      expect(
        draft.state.prompt,
        contains('سلام! شرایط ویزای استارتاپ کانادا چیست؟'),
      );
      expect(draft.state.contextLabel, 'Canada Startup Visa');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('rad_ai_pending_prompt::guest'), contains('🇨🇦'));
      expect(
        prefs.getString('rad_ai_pending_context::guest'),
        'Canada Startup Visa',
      );

      // Saving empty prompt removes keys from storage
      await draft.savePrompt('', null);
      expect(draft.state.hasContent, false);
      expect(prefs.getString('rad_ai_pending_prompt::guest'), isNull);
      expect(prefs.getString('rad_ai_pending_context::guest'), isNull);

      // clearDraft atomically wipes state
      await draft.savePrompt('Temp prompt', 'Context');
      expect(draft.state.hasContent, true);
      await draft.clearDraft();
      expect(draft.state.hasContent, false);
      expect(prefs.getString('rad_ai_pending_prompt::guest'), isNull);
      expect(prefs.getString('rad_ai_pending_context::guest'), isNull);

      draft.dispose();
    },
  );

  test(
    'Consultation draft handles Persian and English Unicode and clearing',
    () async {
      SharedPreferences.setMockInitialValues({});
      final draft = ConsultationDraftNotifier();
      await draft.ready;

      await draft.updateDraft(
        topic: 'مشاوره تحصیلی آلمان ۲۰۲۶',
        message: 'سلام، مدارک تحصیلی من آماده است.\nWhen is the winter semester intake? 🇩🇪\nممنون!',
      );
      expect(draft.state.topic, 'مشاوره تحصیلی آلمان ۲۰۲۶');
      expect(draft.state.message, contains('winter semester intake? 🇩🇪'));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('rad_consultation_draft_topic::guest'),
        'مشاوره تحصیلی آلمان ۲۰۲۶',
      );
      expect(
        prefs.getString('rad_consultation_draft_message::guest'),
        contains('🇩🇪'),
      );

      await draft.clearDraft();
      expect(draft.state.isEmpty, true);
      expect(prefs.getString('rad_consultation_draft_topic::guest'), isNull);
      expect(prefs.getString('rad_consultation_draft_message::guest'), isNull);

      draft.dispose();
    },
  );
}
