abstract class AiService {
  Future<String> ask(String prompt);
}

class PlaceholderAiService implements AiService {
  @override
  Future<String> ask(String prompt) async {
    return 'AI assistant foundation is ready.';
  }
}
