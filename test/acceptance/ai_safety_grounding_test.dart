import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/services/ai/ai_request.dart';
import 'package:rad_emigrate/core/services/ai/ai_response.dart';
import 'package:rad_emigrate/core/services/ai/ai_service.dart';

/// Acceptance: AI system behavior when unavailable — no fabricated requirements.
void main() {
  group('AI safety and grounding (UnavailableAiService)', () {
    late AiService service;

    setUp(() {
      service = UnavailableAiService();
    });

    test('empty prompt does not invent immigration requirements', () async {
      final response = await service.complete(const AiRequest(prompt: '   '));
      expect(response.uncertain, isTrue);
      expect(response.sources, isEmpty);
      expect(response.text.toLowerCase(), contains('please enter'));
      expect(response.text.toLowerCase(), isNot(contains('you must')));
    });

    test('immigration question declines with explicit uncertainty', () async {
      final response = await service.complete(
        const AiRequest(
          prompt: 'What documents do I need for a Canadian study permit?',
          kind: AiRequestKind.immigrationQuestion,
        ),
      );
      expect(response.uncertain, isTrue);
      expect(response.sources, isEmpty);
      expect(response.text, contains('not configured'));
      expect(
        response.text,
        contains('No immigration requirements are inferred'),
      );
    });

    test('document analysis request does not fabricate OCR or advice', () async {
      final response = await service.complete(
        const AiRequest(
          prompt: 'Analyze this passport scan',
          kind: AiRequestKind.documentAnalysis,
        ),
      );
      expect(response.uncertain, isTrue);
      expect(response.sources, isEmpty);
      expect(response.text, contains('not configured'));
    });

    test('legacy ask() preserves uncertainty messaging', () async {
      final text = await service.ask('Is my IELTS score enough?');
      expect(text, contains('not configured'));
      expect(text, contains('No immigration requirements are inferred'));
    });

    test('AiResponse preserves sources when provided by a real provider', () {
      const response = AiResponse(
        text: 'Official guidance summary',
        uncertain: false,
        sources: [
          AiSource(
            title: 'IRCC Study Permit',
            url: 'https://www.canada.ca/example',
            authority: 'OFFICIAL_GOVERNMENT',
          ),
        ],
      );
      expect(response.sources, hasLength(1));
      expect(response.sources.first.authority, 'OFFICIAL_GOVERNMENT');
      expect(response.uncertain, isFalse);
    });

    test('uncertain response may carry empty sources without implying certainty',
        () {
      const response = AiResponse(
        text: 'Insufficient verified evidence.',
        uncertain: true,
        sources: [],
      );
      expect(response.uncertain, isTrue);
      expect(response.sources, isEmpty);
    });
  });
}
