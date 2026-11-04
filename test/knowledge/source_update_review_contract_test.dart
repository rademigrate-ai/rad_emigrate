import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/knowledge/domain/source_update_review_contract.dart';

void main() {
  final source = {
    'id': 'a4100000-0000-4000-8000-000000000010',
    'revision_id': 'a4100000-0000-4000-8000-000000000011',
    'locale': 'fa',
    'delivery_mode': 'frozen_source_readonly',
    'editorial_approved': false,
    'source_policy': 'RAD_CONTENT_PRECEDENCE_V4.1',
    'source_payload_sha256': 'a' * 64,
    'sources': [
      {'url': 'https://digivisa.ir/source', 'body_sha256': 'a' * 64},
    ],
    'rich_sections': [
      {
        'id': 's1',
        'blocks': [
          {
            'id': 'b1',
            'original_structure': {'type': 'paragraph', 'text': 'متن قبلی'},
          },
        ],
      },
    ],
  };
  const newBody = 'ادامه متن منبع رسمی\nمتن جدید مستند\nپایان';
  final digest = sha256.convert(utf8.encode(newBody)).toString();

  Map<String, dynamic> propose({
    Map<String, dynamic>? baseline,
    String sourceUrl = 'https://digivisa.ir/source',
    String blockId = 'b1',
    String expected = 'متن قبلی',
    String body = newBody,
    String? hash,
    String replacement = 'متن جدید مستند',
    String capturedAt = '2026-11-04T10:00:00Z',
  }) => SourceUpdateReviewContract.prepare(
    immutableBaseline: baseline ?? source,
    blockId: blockId,
    expectedOldText: expected,
    sourceUrl: sourceUrl,
    newCapturedBody: body,
    capturedBodySha256: hash ?? digest,
    literalReplacement: replacement,
    capturedAt: capturedAt,
  );

  test('assistant only proposes an evidence-linked human review candidate', () {
    final result = propose();
    expect(result['status'], 'local_review_candidate_only');
    expect(result['approved'], false);
    expect(result['can_publish'], false);
    expect(result['can_auto_publish_feed'], false);
    expect(result['can_write_frozen_snapshot'], false);
    expect(result['must_revalidate_against_live_cms_revision'], true);
    expect(result['base_payload_sha256'], 'a' * 64);
    expect(result['literal_new_text'], 'متن جدید مستند');
  });

  test('no hallucinated passage or source impersonation can enter review', () {
    expect(
      () => propose(replacement: 'ادعای ساخته‌شده'),
      throwsFormatException,
    );
    expect(() => propose(hash: '0' * 64), throwsFormatException);
    expect(
      () => propose(sourceUrl: 'https://untrusted.example/source'),
      throwsFormatException,
    );
    expect(
      () => propose(sourceUrl: 'http://digivisa.ir/source'),
      throwsFormatException,
    );
    expect(() => propose(blockId: 'unknown'), throwsFormatException);
    expect(() => propose(expected: 'متن دیگری'), throwsFormatException);
    expect(() => propose(capturedAt: 'invalid'), throwsFormatException);
    expect(
      () => propose(baseline: {...source, 'editorial_approved': true}),
      throwsFormatException,
    );
  });
}
