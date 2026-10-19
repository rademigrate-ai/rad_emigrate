// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../rad_antigravity_flutter_e2e/lib/features/applications/domain/entities/application_status.dart';
import '../../../rad_antigravity_flutter_e2e/lib/features/applications/domain/entities/visa_application.dart';
import '../../../rad_antigravity_flutter_e2e/lib/features/applications/presentation/providers/case_tracker_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy checklist storage is not exposed to another account', () async {
    SharedPreferences.setMockInitialValues({
      'rad_case_checklist_case-1': '{"caseId":"case-1","applicationStatus":"draft","items":[{"id":"private-step","title":"User A confidential checklist item","status":"notStarted"}]}',
    });
    final prefs = await SharedPreferences.getInstance();
    final controller = CaseTrackerController(
      initialApp: VisaApplication(
        id: 'case-1',
        userId: 'user-b',
        title: 'Study application',
        programName: 'Study Permit',
        country: 'CA',
        status: ApplicationStatus.draft,
        updatedAt: DateTime.utc(2026, 10, 18),
      ),
      userId: 'user-b',
      prefs: prefs,
      nowUtc: DateTime.utc(2026, 10, 18),
    );

    expect(
      controller.state.checklist.items.any(
        (item) => item.title == 'User A confidential checklist item',
      ),
      isFalse,
    );

    controller.dispose();
  });
}
