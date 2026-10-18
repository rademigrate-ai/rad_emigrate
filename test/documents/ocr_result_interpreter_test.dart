import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/documents/domain/ocr_result_interpreter.dart';

void main() {
  const interpreter = OcrResultInterpreter();

  OcrJobSnapshot job({
    OcrJobStatus status = OcrJobStatus.reviewRequired,
    String owner = 'owner-1',
    List<OcrFieldExtraction> fields = const [],
    OcrFailureCode? failure,
  }) {
    return OcrJobSnapshot(
      jobId: 'job-1',
      documentId: 'doc-1',
      ownerUserId: owner,
      status: status,
      fields: fields,
      failure: failure,
    );
  }

  test('cross-owner denied', () {
    final result = interpreter.interpret(job: job(), callerUserId: 'other');
    expect(result.failure, OcrFailureCode.ownerMismatch);
    expect(result.safeForClient, isFalse);
  });

  test('owner sees review fields', () {
    final result = interpreter.interpret(
      job: job(
        fields: const [
          OcrFieldExtraction(key: 'name', value: 'Ada', confidence: 0.95),
        ],
      ),
      callerUserId: 'owner-1',
    );
    expect(result.status, OcrJobStatus.reviewRequired);
    expect(result.displayableFields, hasLength(1));
    expect(result.message, contains('review'));
  });

  test('malformed fields become failure', () {
    final result = interpreter.interpret(
      job: job(
        fields: const [OcrFieldExtraction(key: '', value: '', confidence: 2)],
      ),
      callerUserId: 'owner-1',
    );
    expect(result.failure, OcrFailureCode.malformedExtraction);
  });

  test('running reports progress', () {
    final result = interpreter.interpret(
      job: job(status: OcrJobStatus.running),
      callerUserId: 'owner-1',
    );
    expect(result.status, OcrJobStatus.running);
    expect(result.safeForClient, isTrue);
  });

  test('service may interpret for processing', () {
    final result = interpreter.interpret(
      job: job(
        status: OcrJobStatus.failed,
        failure: OcrFailureCode.rateLimited,
      ),
      callerUserId: 'processor',
      isService: true,
    );
    expect(result.failure, OcrFailureCode.rateLimited);
  });
}
