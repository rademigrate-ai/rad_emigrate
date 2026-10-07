import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/admin/domain/research_source_url.dart';

void main() {
  test('only public HTTPS DNS sources can be saved', () {
    for (final address in [
      'http://example.org',
      'https://127.0.0.1',
      'https://0x7f.0.0.1',
      'https://10.0.0.1',
      'https://169.254.169.254',
      'https://[::1]',
      'https://localhost',
      'https://service.local',
      'https://metadata.google.internal',
      'https://example.org:8080',
      'https://user:password@example.org',
      'https://example.org/#section',
      'https://bad_host.org',
      'https://example.org?value=/',
    ]) {
      expect(parseResearchSourceUrl(address), isNull, reason: address);
    }
    expect(
      parseResearchSourceUrl('https://www.canada.ca/en/immigration.html'),
      isNotNull,
    );
  });

  test('canonical duplicates retain distinct page paths', () {
    String canonical(String value) =>
        canonicalResearchSourceUrl(parseResearchSourceUrl(value)!);
    expect(
      canonical('https://EXAMPLE.org:443/'),
      canonical('https://example.org'),
    );
    expect(canonical('https://example.org/path/'), 'https://example.org/path');
    expect(
      canonical('https://example.org/one'),
      isNot(canonical('https://example.org/two')),
    );
  });
}
