/// Structured AI request for User AI Assistant and future Admin Research Assistant.
enum AiRequestKind {
  general,
  immigrationQuestion,
  documentAnalysis,
  knowledgeSearch,
}

class AiRequest {
  const AiRequest({
    required this.prompt,
    this.kind = AiRequestKind.general,
    this.conversationId,
    this.locale,
    this.metadata = const {},
  });

  final String prompt;
  final AiRequestKind kind;
  final String? conversationId;
  final String? locale;
  final Map<String, String> metadata;
}
