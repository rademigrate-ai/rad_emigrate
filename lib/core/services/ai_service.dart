/// Contract for User AI Assistant and future Admin AI Research Assistant.
abstract class AiService {
  /// Send a user prompt and receive a response.
  /// Future implementations will search the RAD Knowledge Base,
  /// approved external sources, and the web with source attribution.
  Future<String> ask(String prompt);
}

/// Placeholder implementation used until Knowledge Base + RAG is connected.
class PlaceholderAiService implements AiService {
  @override
  Future<String> ask(String prompt) async {
    if (prompt.trim().isEmpty) {
      return 'Please enter a question about immigration, visas, or documents.';
    }
    return 'AI assistant foundation is ready.\n\n'
        'Your question: "$prompt"\n\n'
        'In a future release this will search the RAD Knowledge Base and '
        'authoritative immigration sources. No requirements are fabricated.';
  }
}
