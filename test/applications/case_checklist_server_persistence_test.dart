import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rad_emigrate/features/applications/data/datasources/case_checklist_gateway.dart';
import 'package:rad_emigrate/features/applications/domain/entities/application_status.dart';
import 'package:rad_emigrate/features/applications/domain/entities/case_checklist.dart';
import 'package:rad_emigrate/features/applications/domain/entities/visa_application.dart';
import 'package:rad_emigrate/features/applications/presentation/providers/case_tracker_controller.dart';

class _FakeGateway implements CaseChecklistGateway {
  CaseChecklistSnapshot? snapshot;
  bool rejectSave = false;
  bool rejectLoad = false;
  int saves = 0;

  @override
  Future<CaseChecklistSnapshot?> load(String applicationId) async {
    if (rejectLoad) throw StateError('network unavailable');
    return snapshot;
  }

  @override
  Future<int> save({
    required String applicationId,
    required List<CaseChecklistItem> items,
    required int expectedRevision,
  }) async {
    if (rejectSave) throw StateError('server unavailable');
    if (expectedRevision != (snapshot?.revision ?? 0)) {
      throw StateError('stale edit');
    }
    final nextRevision = expectedRevision + 1;
    snapshot = CaseChecklistSnapshot(
      items: List.unmodifiable(items),
      revision: nextRevision,
    );
    saves++;
    return nextRevision;
  }
}

void main() {
  final app = VisaApplication(
    id: 'a5000000-0000-4000-8000-000000000001',
    userId: 'client-one',
    title: 'Synthetic application',
    programName: 'Unverified program',
    country: 'Test destination',
    status: ApplicationStatus.draft,
    updatedAt: DateTime.utc(2026, 11, 5),
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'server-acknowledged checklist survives new client and empty cache',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final server = _FakeGateway();
      final first = CaseTrackerController(
        initialApp: app,
        userId: 'client-one',
        prefs: prefs,
        gateway: server,
        requireRemotePersistence: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(first.state.isLoading, false);
      await first.addChecklistItem(title: 'Synthetic owned step');
      expect(server.saves, 1);
      expect(server.snapshot!.revision, 1);
      first.dispose();

      await prefs.remove('rad_case_checklist_client-one_${app.id}');
      final second = CaseTrackerController(
        initialApp: app,
        userId: 'client-one',
        prefs: prefs,
        gateway: server,
        requireRemotePersistence: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(second.state.isLoading, false);
      expect(
        second.state.checklist.items.any(
          (item) => item.title == 'Synthetic owned step',
        ),
        true,
      );
      second.dispose();
    },
  );

  test('failed remote save never claims a successful local update', () async {
    final prefs = await SharedPreferences.getInstance();
    final server = _FakeGateway()..rejectSave = true;
    final ctrl = CaseTrackerController(
      initialApp: app,
      userId: 'client-one',
      prefs: prefs,
      gateway: server,
      requireRemotePersistence: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final before = ctrl.state.checklist.items.length;
    await expectLater(
      ctrl.addChecklistItem(title: 'Should never appear'),
      throwsStateError,
    );
    expect(ctrl.state.checklist.items.length, before);
    expect(server.saves, 0);
    ctrl.dispose();
  });

  test(
    'remote load failure cannot silently fall back to local writes',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final server = _FakeGateway()..rejectLoad = true;
      final ctrl = CaseTrackerController(
        initialApp: app,
        userId: 'client-one',
        prefs: prefs,
        gateway: server,
        requireRemotePersistence: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(ctrl.state.errorMessage, contains('disabled'));
      await expectLater(
        ctrl.addChecklistItem(title: 'Reject while offline'),
        throwsStateError,
      );
      expect(server.saves, 0);
      ctrl.dispose();
    },
  );

  test('production mode without backend refuses an apparent save', () async {
    final prefs = await SharedPreferences.getInstance();
    final ctrl = CaseTrackerController(
      initialApp: app,
      userId: 'client-one',
      prefs: prefs,
      requireRemotePersistence: true,
    );
    await expectLater(
      ctrl.addChecklistItem(title: 'No silent local-only save'),
      throwsStateError,
    );
    ctrl.dispose();
  });
}
