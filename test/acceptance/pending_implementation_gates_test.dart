import 'package:flutter_test/flutter_test.dart';

/// Remaining external or deferred gates after Projects 10–15 schema land.
///
/// Schema-backed research/feed/AI gates live in
/// `schema_policy_acceptance_test.dart`. This file only tracks work that is
/// still external (owner actions) or intentionally deferred.
void main() {
  group('External / deferred engineering gates', () {
    test('Super Admin bootstrap requires verified Auth accounts', () {
      // Intended identities (owner-supplied):
      // Super Admin: mehrshad.evol.b@gmail.com
      // Admin: B.rad14@yahoo.com
      // Must be elevated only after Auth user existence is verified;
      // never via client-side email checks alone.
      // This gate needs owner-verified production evidence, not a passing assertion.
    }, skip: 'External/deferred gate — not implemented or verified');

    test('Full Flutter ARB locale service beyond bilingual content model', () {
      // Feed/knowledge already model fa/en. Global ARB package is optional
      // for the web engineering gate.
      // Optional scope; intentionally not counted as an accepted feature.
    });

    test('Data export / account deletion product UI', () {
      // Legal policy text and host-specific flows remain external;
      // schema isolation already owner-scoped for user data.
      // Requires a policy decision and a real product acceptance test.
    });

    test('Production domain, DNS, Auth redirect URLs, app signing', () {
      // This gate needs owner-verified production evidence, not a passing assertion.
    }, skip: 'External/deferred gate — not implemented or verified');
  });
}
