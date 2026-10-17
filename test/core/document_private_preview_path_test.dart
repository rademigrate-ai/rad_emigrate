import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/supabase/supabase_storage.dart';

void main() {
  group('owner-bound private document paths', () {
    test('accepts paths produced by RAD private uploader', () {
      expect(
        isOwnedDocumentStoragePath('user-123/doc-456/report.pdf', 'user-123'),
        isTrue,
      );
      expect(
        isOwnedDocumentStoragePath(
          'user-123/550e8400-e29b-41d4-a716-446655440000/photo.jpg',
          'user-123',
        ),
        isTrue,
      );
    });

    test('rejects paths belonging to other users', () {
      expect(
        isOwnedDocumentStoragePath('other/doc-456/report.pdf', 'user-123'),
        isFalse,
      );
      expect(
        isOwnedDocumentStoragePath('user-123/doc-456/report.pdf', ''),
        isFalse,
      );
    });

    test('rejects remote URLs, traversal and embedded query tokens', () {
      const bad = <String?>[
        null,
        '',
        'https://example.com/report.pdf',
        '/user-123/doc-456/report.pdf',
        'user-123/doc-456/../other.pdf',
        'user-123/../report.pdf',
        'user-123/./report.pdf',
        'user-123//report.pdf',
        'user-123/doc-456/file%2Fsecret.pdf',
        'user-123/doc-456/file.pdf?token=abc',
        'user-123/doc-456/file.pdf#secret',
        'user-123\\doc-456\\report.pdf',
      ];
      for (final path in bad) {
        expect(
          isOwnedDocumentStoragePath(path, 'user-123'),
          isFalse,
          reason: path,
        );
      }
    });
  });
}
