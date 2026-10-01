import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/services/ai/ai_request.dart';
import 'package:rad_emigrate/core/services/ai/ai_service.dart';

void main() {
  test(
    'unavailable AI service clearly declines unsourced immigration guidance',
    () async {
      final response = await UnavailableAiService().complete(
        const AiRequest(prompt: 'What documents do I need?'),
      );

      expect(response.uncertain, isTrue);
      expect(response.sources, isEmpty);
      expect(response.text, contains('not configured'));
      expect(
        response.text,
        contains('No immigration requirements are inferred'),
      );
    },
  );
}
