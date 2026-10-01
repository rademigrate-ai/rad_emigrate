import 'ai_request.dart';
import 'ai_response.dart';

/// Contract for User AI Assistant and Admin AI Research Assistant.
///
/// Implementations must not fabricate immigration requirements.
/// Prefer RAD Knowledge Base → approved sources → web research.
abstract class AiService {
  /// Legacy simple prompt API (kept for existing UI).
  Future<String> ask(String prompt);

  /// Structured request/response API for RAG and document analysis.
  Future<AiResponse> complete(AiRequest request);
}

/// Placeholder until Knowledge Base + RAG is connected.
class PlaceholderAiService implements AiService {
  @override
  Future<String> ask(String prompt) async {
    final response = await complete(AiRequest(prompt: prompt));
    return response.text;
  }

  @override
  Future<AiResponse> complete(AiRequest request) async {
    final prompt = request.prompt.trim();
    if (prompt.isEmpty) {
      return const AiResponse(
        text: 'Please enter a question about immigration, visas, or documents.',
        uncertain: true,
      );
    }
    return AiResponse(
      text: 'AI assistant foundation is ready.\n\n'
          'Your question: "$prompt"\n\n'
          'In a future release this will search the RAD Knowledge Base and '
          'authoritative immigration sources. No requirements are fabricated.',
      uncertain: true,
      sources: const [
        AiSource(
          title: 'RAD Knowledge Base (pending connection)',
          authority: 'RAD',
        ),
      ],
    );
  }
}
