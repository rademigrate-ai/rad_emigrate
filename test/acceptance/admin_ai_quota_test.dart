import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Admin routes must not be constrained by the client five-message gate.
void main() {
  final root = Directory.current.path;
  String read(String relative) => File('$root/$relative').readAsStringSync();

  test('AiAssistantPage does not hard-block admin with _freeLimit', () {
    final page = read(
      'lib/features/ai_assistant/presentation/pages/ai_assistant_page.dart',
    );
    expect(page.contains('static const _freeLimit = 5'), isFalse);
    expect(page.contains('_isPrivilegedAdmin'), isTrue);
    expect(page.contains('widget.adminMode'), isTrue);
    expect(page.contains('_userDisplayHintLimit'), isTrue);
  });

  test('Admin AI workspace is a dedicated page, not only adminMode flag', () {
    final workspace = read(
      'lib/features/admin/presentation/pages/admin_ai_workspace_page.dart',
    );
    expect(workspace.contains('class AdminAiWorkspacePage'), isTrue);
    expect(workspace.contains('AiAssistantPage(adminMode: true)'), isTrue);

    final router = read('lib/core/routing/app_router.dart');
    expect(router.contains('AdminAiWorkspacePage'), isTrue);
    expect(router.contains('/admin/ai-research'), isTrue);
  });

  test('ai-orchestrator enforces server-side daily limits by role', () {
    final fn = read('supabase/functions/ai-orchestrator/index.ts');
    expect(fn.contains('ai_usage_limits'), isTrue);
    expect(fn.contains('daily_limit_reached'), isTrue);
    expect(fn.contains('daily_requests'), isTrue);
  });
}
