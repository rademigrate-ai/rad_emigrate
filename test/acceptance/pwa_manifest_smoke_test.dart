import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Repository-level PWA smoke checks (no deployment).
void main() {
  test('web/manifest.json exists with required icon references', () {
    final file = File('web/manifest.json');
    expect(file.existsSync(), isTrue, reason: 'PWA manifest must exist');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(json['name'], isNotNull);
    expect(json['short_name'], isNotNull);
    expect(json['start_url'], isNotNull);
    expect(json['display'], isNotNull);
    final icons = json['icons'] as List<dynamic>?;
    expect(icons, isNotNull);
    expect(icons!, isNotEmpty);
    for (final icon in icons) {
      final map = icon as Map<String, dynamic>;
      expect(map['src'], isNotEmpty);
      expect(map['sizes'], isNotEmpty);
      expect(map['type'], isNotEmpty);
      final iconFile = File('web/${map['src']}');
      expect(
        iconFile.existsSync(),
        isTrue,
        reason: 'Referenced icon missing: ${map['src']}',
      );
    }
  });

  test('manifest name is present (production branding may still lag)', () {
    final json =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    // Document current state; Master Agent owns production branding polish.
    expect(json['name'], isA<String>());
    expect((json['name'] as String).isNotEmpty, isTrue);
  });
}
