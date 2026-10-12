import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/routing/auth_redirect.dart';

/// Journey 6 + 8: Profile and Feed are real protected routes in the router.
void main() {
  test('UJ06 /profile is a known protected destination', () {
    expect(restoredProtectedDestination('/profile'), '/profile');
  });

  test('UJ08 /feed is a known protected destination', () {
    expect(restoredProtectedDestination('/feed'), '/feed');
  });

  test('UJ06b router source registers profile and feed shell routes', () {
    final router = File('lib/core/routing/app_router.dart').readAsStringSync();
    expect(router, contains("path: '/profile'"));
    expect(router, contains('ProfilePage'));
    expect(router, contains("path: '/feed'"));
    expect(router, contains('FeedPage'));
    expect(router, contains("path: '/consultation'"));
    expect(router, contains('ConsultationPage'));
    expect(router, contains("path: '/visa'"));
    expect(router, contains('VisaPage'));
    expect(router, contains("path: '/applications'"));
  });

  test('UJ08b feed page source is read-oriented (no publish mutation UI)', () {
    final feed = File('lib/features/feed/presentation/pages/feed_page.dart')
        .readAsStringSync();
    expect(feed.toLowerCase(), isNot(contains('publish_content_draft')));
    expect(feed, contains('FeedPage'));
  });
}
