import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/identity_draft_store.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

class ConsultationDraft {
  const ConsultationDraft({this.topic = '', this.message = ''});

  final String topic;
  final String message;

  bool get isEmpty => topic.trim().isEmpty && message.trim().isEmpty;
  bool get hasContent => topic.trim().isNotEmpty || message.trim().isNotEmpty;

  ConsultationDraft copyWith({String? topic, String? message}) {
    return ConsultationDraft(
      topic: topic ?? this.topic,
      message: message ?? this.message,
    );
  }
}

class ConsultationDraftNotifier extends StateNotifier<ConsultationDraft> {
  ConsultationDraftNotifier({String? userId})
    : _store = IdentityDraftStore([
        'rad_consultation_draft_topic',
        'rad_consultation_draft_message',
      ], userId: userId),
      super(const ConsultationDraft()) {
    ready = _loadFromStorage();
  }

  final IdentityDraftStore _store;
  Future<void> prepareSignIn() => _store.signInHandoff();

  static const _prefTopic = 'rad_consultation_draft_topic';
  static const _prefMessage = 'rad_consultation_draft_message';
  bool _loaded = false;
  late final Future<void> ready;

  Future<void> _loadFromStorage() async {
    try {
      final values = await _store.load();
      if (!mounted || _loaded) return;
      final topic = values[_prefTopic] ?? '';
      final message = values[_prefMessage] ?? '';
      if (!_loaded) {
        state = ConsultationDraft(topic: topic, message: message);
        _loaded = true;
      }
    } catch (_) {}
  }

  Future<void> updateDraft({String? topic, String? message}) async {
    _loaded = true;
    state = state.copyWith(topic: topic, message: message);
    try {
      if (topic != null) await _store.write(_prefTopic, topic);
      if (message != null) await _store.write(_prefMessage, message);
    } catch (_) {}
  }

  Future<void> clearDraft() async {
    _loaded = true;
    state = const ConsultationDraft();
    try {
      await _store.clear();
    } catch (_) {}
  }
}

final consultationDraftProvider =
    StateNotifierProvider<ConsultationDraftNotifier, ConsultationDraft>((ref) {
      return ConsultationDraftNotifier(
        userId: ref.watch(authenticatedUserIdProvider),
      );
    });
