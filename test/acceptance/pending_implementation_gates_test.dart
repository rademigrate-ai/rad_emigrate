import 'package:flutter_test/flutter_test.dart';

/// Remaining external or deferred gates after Projects 10–15 schema land.
///
/// Schema-backed research/feed/AI gates live in
/// `schema_policy_acceptance_test.dart`. This file only tracks work that is
/// still external (owner actions) or intentionally deferred.
void main() {
  group('External / deferred engineering gates', () {
    test(
      'Super Admin bootstrap requires verified Auth accounts',
      () {},
      skip: 'External owner action: verify Auth identities before elevation.',
    );

    test(
      'Full Flutter ARB locale service beyond bilingual content model',
      () {},
      skip: 'Deferred optional localization architecture; not a pass claim.',
    );

    test(
      'Data export / account deletion product UI',
      () {},
      skip: 'Deferred pending owner legal and retention policy.',
    );

    test(
      'Production domain, DNS, Auth redirect URLs, app signing',
      () {},
      skip: 'External infrastructure and owner signing action.',
    );
  });
}
