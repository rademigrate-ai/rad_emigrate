import 'ai_request.dart';
import 'ai_response.dart';

/// Contract for User AI Assistant and Admin AI Research Assistant.
///
/// Implementations must not fabricate immigration requirements.
/// Prefer RAD Knowledge Base → approved sources → web research.
abstract class AiService {
  /// Whether this implementation can currently produce sourced answers.
  bool get isAvailable => true;

  /// Legacy simple prompt API (kept for existing UI).
  Future<String> ask(String prompt);

  /// Structured request/response API for RAG and document analysis.
  Future<AiResponse> complete(AiRequest request);
}

/// Used until a configured RAD Knowledge Base provider is available.
class UnavailableAiService implements AiService {
  @override
  bool get isAvailable => false;

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
      text:
          'The RAD Knowledge Base is not configured for this build.\n\n'
          'Your question: "$prompt"\n\n'
          'Configure the approved RAD Knowledge Base provider to enable '
          'sourced answers. No immigration requirements are inferred here.',
      uncertain: true,
    );
  }
}
