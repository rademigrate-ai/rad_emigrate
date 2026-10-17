import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/admin/data/review_snapshot_provenance.dart';

void main() {
  group('review-only research snapshot source URL validation', () {
    test('accepts a successful existing HTTPS evidence URL', () {
      expect(
        verifiedReviewSnapshotUrl(
          canonicalUrl: ' https://radvisa.com/visa-guide ',
          httpStatus: 200,
          removedAt: null,
        ),
        'https://radvisa.com/visa-guide',
      );
    });

    test('rejects missing, removed or failed-source snapshots', () {
      for (final value in <Object?>[null, 10, 'https://']) {
        expect(
          verifiedReviewSnapshotUrl(
            canonicalUrl: value,
            httpStatus: 200,
            removedAt: null,
          ),
          isNull,
        );
      }
      expect(
        verifiedReviewSnapshotUrl(
          canonicalUrl: 'https://radvisa.com/visa',
          httpStatus: 404,
          removedAt: null,
        ),
        isNull,
      );
      expect(
        verifiedReviewSnapshotUrl(
          canonicalUrl: 'https://radvisa.com/visa',
          httpStatus: 200,
          removedAt: '2026-10-15T12:00:00Z',
        ),
        isNull,
      );
    });

    test('rejects unsafe or ambiguous URL origins', () {
      const unsafe = <String>[
        'http://radvisa.com/visa',
        'javascript:alert(1)',
        'https://person:password@radvisa.com/visa',
        'https://localhost/admin',
        'https://127.0.0.1/private',
        '/internal/relative',
        'https://',
        'ftp://radvisa.com/source',
      ];
      for (final source in unsafe) {
        expect(
          verifiedReviewSnapshotUrl(
            canonicalUrl: source,
            httpStatus: 200,
            removedAt: null,
          ),
          isNull,
          reason: source,
        );
      }
    });
  });
}
