import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConsultationDraft {
  const ConsultationDraft({
    this.topic = '',
    this.message = '',
  });

  final String topic;
  final String message;

  bool get isEmpty => topic.trim().isEmpty && message.trim().isEmpty;
  bool get hasContent => topic.trim().isNotEmpty || message.trim().isNotEmpty;

  ConsultationDraft copyWith({
    String? topic,
    String? message,
  }) {
    return ConsultationDraft(
      topic: topic ?? this.topic,
      message: message ?? this.message,
    );
  }
}

class ConsultationDraftNotifier extends StateNotifier<ConsultationDraft> {
  ConsultationDraftNotifier() : super(const ConsultationDraft()) {
    ready = _loadFromStorage();
  }

  static const _prefTopic = 'rad_consultation_draft_topic';
  static const _prefMessage = 'rad_consultation_draft_message';
  bool _loaded = false;
  late final Future<void> ready;

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_loaded) return;
      final topic = prefs.getString(_prefTopic) ?? '';
      final message = prefs.getString(_prefMessage) ?? '';
      if (!_loaded) {
        state = ConsultationDraft(
          topic: topic,
          message: message,
        );
        _loaded = true;
      }
    } catch (_) {}
  }

  Future<void> updateDraft({String? topic, String? message}) async {
    _loaded = true;
    state = state.copyWith(topic: topic, message: message);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (topic != null) await prefs.setString(_prefTopic, topic);
      if (message != null) await prefs.setString(_prefMessage, message);
    } catch (_) {}
  }

  Future<void> clearDraft() async {
    _loaded = true;
    state = const ConsultationDraft();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefTopic);
      await prefs.remove(_prefMessage);
    } catch (_) {}
  }
}

final consultationDraftProvider =
    StateNotifierProvider<ConsultationDraftNotifier, ConsultationDraft>((ref) {
      return ConsultationDraftNotifier();
    });
