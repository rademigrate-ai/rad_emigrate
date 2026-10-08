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
    expect(page.contains('_used >= '), isFalse);
    expect(page.contains('widget.adminMode'), isTrue);
    expect(page.contains("scope: widget.adminMode ? 'admin' : 'user'"), isTrue);
  });

  test('Admin AI workspace is a dedicated page, not only adminMode flag', () {
    final workspace = read(
      'lib/features/admin/presentation/pages/admin_ai_workspace_page.dart',
    );
    expect(workspace.contains('class AdminAiWorkspacePage'), isTrue);
    expect(workspace.contains('adminMode: true'), isTrue);
    expect(workspace.contains('AiAssistantPage('), isTrue);

    final router = read('lib/core/routing/app_router.dart');
    expect(router.contains('AdminAiWorkspacePage'), isTrue);
    expect(router.contains('/admin/ai-research'), isTrue);
  });

  test('ai-orchestrator enforces server-side daily limits by role', () {
    final fn = read('supabase/functions/ai-orchestrator/handler.ts');
    expect(fn.contains('rpc/consume_ai_daily_quota'), isTrue);
    expect(fn.contains('daily_limit_reached'), isTrue);
    expect(fn.contains('p_role: role'), isTrue);
  });
}
