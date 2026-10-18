/// Domain interpretation of OCR processing outcomes.
///
/// Mirrors backend atomic OCR contracts without calling Storage or Edge.
/// Ownership checks are explicit; cross-owner access is denied.
library;

enum OcrJobStatus { queued, running, reviewRequired, failed, cancelled }

enum OcrFailureCode {
  ownerMismatch,
  invalidMime,
  payloadTooLarge,
  leaseConflict,
  providerUnavailable,
  malformedExtraction,
  rateLimited,
  unknown,
}

class OcrFieldExtraction {
  const OcrFieldExtraction({
    required this.key,
    required this.value,
    required this.confidence,
  });

  final String key;
  final String value;
  final double confidence;

  bool get isWellFormed =>
      key.trim().isNotEmpty &&
      value.trim().isNotEmpty &&
      confidence >= 0 &&
      confidence <= 1;
}

class OcrJobSnapshot {
  const OcrJobSnapshot({
    required this.jobId,
    required this.documentId,
    required this.ownerUserId,
    required this.status,
    this.fields = const [],
    this.failure,
    this.retryAfterSeconds,
  });

  final String jobId;
  final String documentId;
  final String ownerUserId;
  final OcrJobStatus status;
  final List<OcrFieldExtraction> fields;
  final OcrFailureCode? failure;
  final int? retryAfterSeconds;
}

class OcrInterpretation {
  const OcrInterpretation({
    required this.status,
    required this.safeForClient,
    this.displayableFields = const [],
    this.failure,
    this.retryAfterSeconds,
    this.message = '',
  });

  final OcrJobStatus status;
  final bool safeForClient;
  final List<OcrFieldExtraction> displayableFields;
  final OcrFailureCode? failure;
  final int? retryAfterSeconds;
  final String message;
}

/// Interprets OCR job snapshots for domain consumers.
class OcrResultInterpreter {
  const OcrResultInterpreter();

  /// Caller must own the document unless acting as service for processing.
  OcrInterpretation interpret({
    required OcrJobSnapshot job,
    required String callerUserId,
    bool isService = false,
  }) {
    if (!isService && callerUserId != job.ownerUserId) {
      return const OcrInterpretation(
        status: OcrJobStatus.failed,
        safeForClient: false,
        failure: OcrFailureCode.ownerMismatch,
        message: 'Document is not accessible.',
      );
    }

    switch (job.status) {
      case OcrJobStatus.queued:
      case OcrJobStatus.running:
        return OcrInterpretation(
          status: job.status,
          safeForClient: true,
          message: 'Processing in progress.',
          retryAfterSeconds: job.retryAfterSeconds,
        );
      case OcrJobStatus.cancelled:
        return const OcrInterpretation(
          status: OcrJobStatus.cancelled,
          safeForClient: true,
          message: 'Processing was cancelled.',
        );
      case OcrJobStatus.failed:
        return OcrInterpretation(
          status: OcrJobStatus.failed,
          safeForClient: true,
          failure: job.failure ?? OcrFailureCode.unknown,
          retryAfterSeconds: job.retryAfterSeconds,
          message: _failureMessage(job.failure ?? OcrFailureCode.unknown),
        );
      case OcrJobStatus.reviewRequired:
        final good = job.fields.where((f) => f.isWellFormed).toList();
        if (job.fields.isNotEmpty && good.isEmpty) {
          return const OcrInterpretation(
            status: OcrJobStatus.failed,
            safeForClient: true,
            failure: OcrFailureCode.malformedExtraction,
            message: 'Extraction could not be interpreted.',
          );
        }
        return OcrInterpretation(
          status: OcrJobStatus.reviewRequired,
          safeForClient: true,
          displayableFields: good,
          message: 'Human review required before use.',
        );
    }
  }

  static String _failureMessage(OcrFailureCode code) => switch (code) {
    OcrFailureCode.ownerMismatch => 'Document is not accessible.',
    OcrFailureCode.invalidMime => 'File type is not supported.',
    OcrFailureCode.payloadTooLarge => 'File exceeds size limit.',
    OcrFailureCode.leaseConflict =>
      'Another processing attempt is already in progress.',
    OcrFailureCode.providerUnavailable =>
      'Document processing is temporarily unavailable.',
    OcrFailureCode.malformedExtraction =>
      'Extraction could not be interpreted.',
    OcrFailureCode.rateLimited =>
      'Processing limit reached. Please try again later.',
    OcrFailureCode.unknown => 'Document processing failed.',
  };
}
