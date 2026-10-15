import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConsultationDraft {
  const ConsultationDraft({
    this.topic = '',
    this.message = '',
    this.pendingSubmit = false,
    this.submissionToken,
  });

  final String topic;
  final String message;
  final bool pendingSubmit;
  final String? submissionToken;

  bool get isEmpty => topic.trim().isEmpty && message.trim().isEmpty;
  bool get hasContent => topic.trim().isNotEmpty || message.trim().isNotEmpty;

  ConsultationDraft copyWith({
    String? topic,
    String? message,
    bool? pendingSubmit,
    String? submissionToken,
    bool clearToken = false,
  }) {
    return ConsultationDraft(
      topic: topic ?? this.topic,
      message: message ?? this.message,
      pendingSubmit: pendingSubmit ?? this.pendingSubmit,
      submissionToken: clearToken
          ? null
          : (submissionToken ?? this.submissionToken),
    );
  }
}

class ConsultationDraftNotifier extends StateNotifier<ConsultationDraft> {
  ConsultationDraftNotifier() : super(const ConsultationDraft()) {
    _loadFromStorage();
  }

  static const _prefTopic = 'rad_consultation_draft_topic';
  static const _prefMessage = 'rad_consultation_draft_message';
  static const _prefPending = 'rad_consultation_draft_pending';
  static const _prefToken = 'rad_consultation_draft_token';
  bool _loaded = false;

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_loaded) return;
      final topic = prefs.getString(_prefTopic) ?? '';
      final message = prefs.getString(_prefMessage) ?? '';
      final pending = prefs.getBool(_prefPending) ?? false;
      final token = prefs.getString(_prefToken);
      if (!_loaded) {
        state = ConsultationDraft(
          topic: topic,
          message: message,
          pendingSubmit: pending,
          submissionToken: token,
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

  Future<void> markPendingSubmission(String token) async {
    _loaded = true;
    state = state.copyWith(pendingSubmit: true, submissionToken: token);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefPending, true);
      await prefs.setString(_prefToken, token);
    } catch (_) {}
  }

  Future<void> clearPendingSubmission() async {
    _loaded = true;
    state = state.copyWith(pendingSubmit: false, clearToken: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefPending);
      await prefs.remove(_prefToken);
    } catch (_) {}
  }

  Future<void> clearDraft() async {
    _loaded = true;
    state = const ConsultationDraft();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefTopic);
      await prefs.remove(_prefMessage);
      await prefs.remove(_prefPending);
      await prefs.remove(_prefToken);
    } catch (_) {}
  }
}

final consultationDraftProvider =
    StateNotifierProvider<ConsultationDraftNotifier, ConsultationDraft>((ref) {
      return ConsultationDraftNotifier();
    });
