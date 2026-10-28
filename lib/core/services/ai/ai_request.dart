/// Structured AI request for User AI Assistant and future Admin Research Assistant.
enum AiRequestKind {
  general,
  immigrationQuestion,
  documentAnalysis,
  knowledgeSearch,
}

class AiConversationMessage {
  const AiConversationMessage({required this.isUser, required this.text});

  final bool isUser;
  final String text;
}

class AiRequest {
  const AiRequest({
    required this.prompt,
    this.kind = AiRequestKind.general,
    this.conversationId,
    this.locale,
    this.history = const [],
    this.metadata = const {},
    this.authorizedDataScopes = const [],
    this.context = const {},
    this.webSearchMode = 'auto',
  });

  final String prompt;
  final AiRequestKind kind;
  final String? conversationId;
  final String? locale;

  /// Prior conversation turns, excluding local failure notices.
  final List<AiConversationMessage> history;
  final Map<String, String> metadata;

  /// Explicit user-authorized tool scopes, separate from display metadata.
  final List<String> authorizedDataScopes;
  final Map<String, String?> context;

  /// auto | on | off — server-side web research mode.
  final String webSearchMode;
}

