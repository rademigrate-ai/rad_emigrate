/// Structured AI response with optional source attribution.
class AiSource {
  const AiSource({
    required this.title,
    this.url,
    this.authority,
  });

  final String title;
  final String? url;
  final String? authority;
}

class AiResponse {
  const AiResponse({
    required this.text,
    this.sources = const [],
    this.uncertain = false,
    this.conversationId,
  });

  final String text;
  final List<AiSource> sources;
  final bool uncertain;
  final String? conversationId;
}
