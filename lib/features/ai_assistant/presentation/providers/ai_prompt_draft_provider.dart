import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiPromptDraft {
  const AiPromptDraft({this.prompt = '', this.contextLabel});

  final String prompt;
  final String? contextLabel;

  bool get hasContent => prompt.trim().isNotEmpty;
}

class AiPromptDraftNotifier extends StateNotifier<AiPromptDraft> {
  AiPromptDraftNotifier() : super(const AiPromptDraft()) {
    ready = _load();
  }

  static const _prefPrompt = 'rad_ai_pending_prompt';
  static const _prefContext = 'rad_ai_pending_context';
  bool _loaded = false;
  late final Future<void> ready;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_loaded) return;
      final p = prefs.getString(_prefPrompt) ?? '';
      final c = prefs.getString(_prefContext);
      if (!_loaded) {
        state = AiPromptDraft(prompt: p, contextLabel: c);
        _loaded = true;
      }
    } catch (_) {}
  }

  Future<void> savePrompt(String prompt, [String? contextLabel]) async {
    _loaded = true;
    state = AiPromptDraft(prompt: prompt, contextLabel: contextLabel);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefPrompt, prompt);
      if (contextLabel != null) {
        await prefs.setString(_prefContext, contextLabel);
      } else {
        await prefs.remove(_prefContext);
      }
    } catch (_) {}
  }

  Future<String?> consumePrompt() async {
    await ready;
    _loaded = true;
    final p = state.prompt;
    state = const AiPromptDraft();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefPrompt);
      await prefs.remove(_prefContext);
    } catch (_) {}
    return p.isNotEmpty ? p : null;
  }
}

final aiPromptDraftProvider =
    StateNotifierProvider<AiPromptDraftNotifier, AiPromptDraft>((ref) {
      return AiPromptDraftNotifier();
    });
