import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/admin/data/admin_operations_repository.dart';

/// Acceptance: client-visible role values never grant authority by themselves.
/// Server/RLS is the authority boundary; AdminSnapshot only reflects it.
void main() {
  group('AdminSnapshot role authorization', () {
    test('USER role cannot access admin operations', () {
      const snapshot = AdminSnapshot(
        role: 'user',
        applications: 0,
        documents: 0,
        researchJobs: 0,
        aiRequests: 0,
        documentJobs: 0,
        openTasks: 0,
        auditEvents: 0,
      );
      expect(snapshot.canAccess, isFalse);
      expect(snapshot.isSuperAdmin, isFalse);
    });

    test('ADMIN role can access operations but is not Super Admin', () {
      const snapshot = AdminSnapshot(
        role: 'admin',
        applications: 3,
        documents: 1,
        researchJobs: 0,
        aiRequests: 2,
        documentJobs: 0,
        openTasks: 1,
        auditEvents: 0,
      );
      expect(snapshot.canAccess, isTrue);
      expect(snapshot.isSuperAdmin, isFalse);
    });

    test('SUPER_ADMIN role can access operations and audit events', () {
      const snapshot = AdminSnapshot(
        role: 'super_admin',
        applications: 10,
        documents: 4,
        researchJobs: 2,
        aiRequests: 8,
        documentJobs: 1,
        openTasks: 3,
        auditEvents: 12,
      );
      expect(snapshot.canAccess, isTrue);
      expect(snapshot.isSuperAdmin, isTrue);
    });

    test('arbitrary client role strings do not grant access', () {
      for (final forged in [
        'USER',
        'Admin',
        'SUPER_ADMIN',
        'administrator',
        'root',
        '',
        'admin; drop table',
      ]) {
        final snapshot = AdminSnapshot(
          role: forged,
          applications: 99,
          documents: 99,
          researchJobs: 99,
          aiRequests: 99,
          documentJobs: 99,
          openTasks: 99,
          auditEvents: 99,
        );
        // Only exact lowercase server roles grant access.
        final allowed = forged == 'admin' || forged == 'super_admin';
        expect(snapshot.canAccess, allowed, reason: 'forged role: $forged');
      }
    });

    test(
      'USER cannot become ADMIN through client-side role mutation model',
      () {
        // Domain model has no public setter that elevates role; role is
        // read-only.
        const user = AdminSnapshot(
          role: 'user',
          applications: 0,
          documents: 0,
          researchJobs: 0,
          aiRequests: 0,
          documentJobs: 0,
          openTasks: 0,
          auditEvents: 0,
        );
        // Constructing a new snapshot with elevated role is a different
        // object; the original remains non-privileged.
        expect(user.role, 'user');
        expect(user.canAccess, isFalse);
      },
    );
  });
}
