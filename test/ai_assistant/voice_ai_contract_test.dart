import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/ai_assistant/domain/voice_ai_contract.dart';

void main() {
  final contract = VoiceAiContract();

  test('unsupported locale fails immediately', () {
    final s = contract.startListening(locale: 'de');
    expect(s.state, VoiceSessionState.failed);
    expect(s.failure, VoiceFailureKind.unsupportedLocale);
  });

  test('happy path en → speaking with uncertainty without citations', () {
    var s = contract.startListening(locale: 'en');
    expect(s.state, VoiceSessionState.listening);
    s = contract.acceptTranscript(
      current: s,
      transcript: const VoiceTranscript(
        text: 'What is Express Entry?',
        locale: 'en',
        confidence: 0.9,
        isFinal: true,
      ),
    );
    expect(s.state, VoiceSessionState.generating);
    s = contract.completeGeneration(
      current: s,
      response: const VoiceAiResponse(
        replyText: 'I can outline general concepts; verify on IRCC.',
        locale: 'en',
        uncertain: false,
        citations: [],
      ),
    );
    expect(s.state, VoiceSessionState.speaking);
    expect(s.response!.uncertain, isTrue);
  });

  test('empty transcript fails', () {
    final s = contract.acceptTranscript(
      current: const VoiceSession(state: VoiceSessionState.listening),
      transcript: const VoiceTranscript(
        text: '  ',
        locale: 'fa',
        confidence: 0.5,
        isFinal: true,
      ),
    );
    expect(s.failure, VoiceFailureKind.transcriptionFailed);
  });

  test('cancel from listening', () {
    final s = contract.cancel(
      const VoiceSession(state: VoiceSessionState.listening),
    );
    expect(s.state, VoiceSessionState.cancelled);
  });

  test('failure messages are sanitized', () {
    expect(
      VoiceAiContract.failureMessage(VoiceFailureKind.providerUnavailable),
      isNot(contains('stack')),
    );
  });

  test('persian session starts', () {
    final s = contract.startListening(locale: 'fa');
    expect(s.state, VoiceSessionState.listening);
  });

  test('recover after timeout returns to listening', () {
    final failed = contract.fail(
      current: const VoiceSession(state: VoiceSessionState.listening),
      kind: VoiceFailureKind.timeout,
    );
    final recovered = contract.recoverAfterRetryableFailure(
      current: failed,
      locale: 'en',
    );
    expect(recovered.state, VoiceSessionState.listening);
  });

  test('permission denied is not retryable recovery', () {
    final failed = contract.fail(
      current: const VoiceSession(state: VoiceSessionState.listening),
      kind: VoiceFailureKind.permissionDenied,
    );
    final recovered = contract.recoverAfterRetryableFailure(
      current: failed,
      locale: 'en',
    );
    expect(recovered.state, VoiceSessionState.failed);
  });
}
