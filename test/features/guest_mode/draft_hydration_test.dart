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
        'rad_ai_pending_prompt': 'Saved visa question',
        'rad_ai_pending_context': 'Canada',
      });
      final draft = AiPromptDraftNotifier();
      await draft.ready;
      expect(draft.state.prompt, 'Saved visa question');
      expect(draft.state.contextLabel, 'Canada');
      expect(await draft.consumePrompt(), 'Saved visa question');
      expect(draft.state.hasContent, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('rad_ai_pending_prompt'), isNull);
        draft.dispose();
    },
  );

  test('Consultation draft hydrates without pending submission', () async {
    SharedPreferences.setMockInitialValues({
      'rad_consultation_draft_topic': 'Study',
      'rad_consultation_draft_message': 'Please advise',
    });
    final draft = ConsultationDraftNotifier();
    await draft.ready;
    expect(draft.state.topic, 'Study');
    expect(draft.state.message, 'Please advise');
    await draft.clearDraft();
    expect(draft.state.isEmpty, true);
    draft.dispose();
  });
}
