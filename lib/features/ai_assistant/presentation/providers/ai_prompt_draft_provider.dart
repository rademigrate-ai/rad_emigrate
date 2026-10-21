import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/identity_draft_store.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

class AiPromptDraft {
  const AiPromptDraft({this.prompt = '', this.contextLabel});

  final String prompt;
  final String? contextLabel;

  bool get hasContent => prompt.trim().isNotEmpty;
}

class AiPromptDraftNotifier extends StateNotifier<AiPromptDraft> {
  AiPromptDraftNotifier({String? userId})
    : _store = IdentityDraftStore([
        'rad_ai_pending_prompt',
        'rad_ai_pending_context',
      ], userId: userId),
      super(const AiPromptDraft()) {
    ready = _load();
  }

  final IdentityDraftStore _store;
  Future<void> prepareSignIn() => _store.signInHandoff();

  static const _prefPrompt = 'rad_ai_pending_prompt';
  static const _prefContext = 'rad_ai_pending_context';
  bool _loaded = false;
  late final Future<void> ready;

  Future<void> _load() async {
    try {
      final values = await _store.load();
      if (!mounted || _loaded) return;
      final p = values[_prefPrompt] ?? '';
      final c = values[_prefContext];
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
      await _store.write(_prefPrompt, prompt);
      await _store.write(_prefContext, contextLabel);
    } catch (_) {}
  }

  Future<void> clearDraft() async {
    _loaded = true;
    state = const AiPromptDraft();
    try {
      await _store.clear();
    } catch (_) {}
  }

  Future<String?> consumePrompt() async {
    await ready;
    _loaded = true;
    final p = state.prompt;
    state = const AiPromptDraft();
    try {
      await _store.clear();
    } catch (_) {}
    return p.isNotEmpty ? p : null;
  }
}

final aiPromptDraftProvider =
    StateNotifierProvider<AiPromptDraftNotifier, AiPromptDraft>((ref) {
      return AiPromptDraftNotifier(
        userId: ref.watch(authenticatedUserIdProvider),
      );
    });
