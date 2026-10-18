/// Provider-independent Voice AI domain contract.
///
/// Encodes supported states without binding to a specific STT/TTS vendor.
/// Real provider verification remains an external dependency.
library;

enum VoiceSessionState {
  idle,
  listening,
  transcribing,
  generating,
  speaking,
  failed,
  cancelled,
}

enum VoiceFailureKind {
  permissionDenied,
  transcriptionFailed,
  generationFailed,
  synthesisFailed,
  timeout,
  unsupportedLocale,
  providerUnavailable,
}

class VoiceTranscript {
  const VoiceTranscript({
    required this.text,
    required this.locale,
    required this.confidence,
    this.isFinal = false,
  });

  final String text;
  final String locale;
  final double confidence;
  final bool isFinal;

  bool get isUsable =>
      isFinal &&
      text.trim().isNotEmpty &&
      confidence >= 0.0 &&
      confidence <= 1.0;
}

class VoiceAiResponse {
  const VoiceAiResponse({
    required this.replyText,
    required this.locale,
    this.uncertain = true,
    this.citations = const [],
  });

  final String replyText;
  final String locale;
  final bool uncertain;
  final List<String> citations;
}

class VoiceSession {
  const VoiceSession({
    required this.state,
    this.transcript,
    this.response,
    this.failure,
  });

  final VoiceSessionState state;
  final VoiceTranscript? transcript;
  final VoiceAiResponse? response;
  final VoiceFailureKind? failure;
}

/// Deterministic state transitions for voice workflows.
class VoiceAiContract {
  static const supportedLocales = {'en', 'fa'};

  VoiceSession startListening({required String locale}) {
    if (!supportedLocales.contains(locale)) {
      return const VoiceSession(
        state: VoiceSessionState.failed,
        failure: VoiceFailureKind.unsupportedLocale,
      );
    }
    return const VoiceSession(state: VoiceSessionState.listening);
  }

  VoiceSession acceptTranscript({
    required VoiceSession current,
    required VoiceTranscript transcript,
  }) {
    if (current.state != VoiceSessionState.listening &&
        current.state != VoiceSessionState.transcribing) {
      return VoiceSession(
        state: VoiceSessionState.failed,
        failure: VoiceFailureKind.transcriptionFailed,
        transcript: transcript,
      );
    }
    if (!transcript.isUsable) {
      return VoiceSession(
        state: VoiceSessionState.failed,
        failure: VoiceFailureKind.transcriptionFailed,
        transcript: transcript,
      );
    }
    return VoiceSession(
      state: VoiceSessionState.generating,
      transcript: transcript,
    );
  }

  VoiceSession completeGeneration({
    required VoiceSession current,
    required VoiceAiResponse response,
  }) {
    if (current.state != VoiceSessionState.generating) {
      return VoiceSession(
        state: VoiceSessionState.failed,
        failure: VoiceFailureKind.generationFailed,
        transcript: current.transcript,
      );
    }
    if (response.replyText.trim().isEmpty) {
      return VoiceSession(
        state: VoiceSessionState.failed,
        failure: VoiceFailureKind.generationFailed,
        transcript: current.transcript,
      );
    }
    // Spoken answers remain uncertain unless citations are explicit.
    final safe = VoiceAiResponse(
      replyText: response.replyText.trim(),
      locale: response.locale,
      uncertain: response.citations.isEmpty ? true : response.uncertain,
      citations: response.citations,
    );
    return VoiceSession(
      state: VoiceSessionState.speaking,
      transcript: current.transcript,
      response: safe,
    );
  }

  VoiceSession fail({
    required VoiceSession current,
    required VoiceFailureKind kind,
  }) {
    return VoiceSession(
      state: VoiceSessionState.failed,
      transcript: current.transcript,
      response: current.response,
      failure: kind,
    );
  }

  VoiceSession cancel(VoiceSession current) {
    return VoiceSession(
      state: VoiceSessionState.cancelled,
      transcript: current.transcript,
      response: current.response,
    );
  }

  /// Retryable failures may return to listening for the same locale.
  VoiceSession recoverAfterRetryableFailure({
    required VoiceSession current,
    required String locale,
  }) {
    if (current.state != VoiceSessionState.failed) {
      return current;
    }
    final kind = current.failure;
    final retryable =
        kind == VoiceFailureKind.timeout ||
        kind == VoiceFailureKind.transcriptionFailed ||
        kind == VoiceFailureKind.providerUnavailable ||
        kind == VoiceFailureKind.generationFailed;
    if (!retryable) return current;
    return startListening(locale: locale);
  }

  /// Sanitized user-visible messages — no provider internals.
  static String failureMessage(VoiceFailureKind kind) => switch (kind) {
    VoiceFailureKind.permissionDenied =>
      'Microphone permission is required for voice input.',
    VoiceFailureKind.transcriptionFailed =>
      'Could not transcribe speech. Please try again or type your question.',
    VoiceFailureKind.generationFailed =>
      'Could not generate a spoken answer right now.',
    VoiceFailureKind.synthesisFailed => 'Could not play the spoken answer.',
    VoiceFailureKind.timeout => 'Voice request timed out.',
    VoiceFailureKind.unsupportedLocale =>
      'This language is not supported for voice yet.',
    VoiceFailureKind.providerUnavailable =>
      'Voice service is temporarily unavailable.',
  };
}
