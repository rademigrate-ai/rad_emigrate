import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.path;
  String read(String relative) => File('$root/$relative').readAsStringSync();

  late String p0Sql;
  late String alignmentSql;

  setUpAll(() {
    p0Sql = read(
      'supabase/migrations/20261010010000_stage1_p0_security_completion.sql',
    );
    alignmentSql = read(
      'supabase/migrations/20261012110945_stage1_security_abuse_storage_alignment.sql',
    );
  });

  test('quota and entitlement decisions reject a non-owner user id', () {
    expect(
      RegExp(
        r"auth\.uid\(\) is distinct from p_user_id[\s\S]{0,100}raise exception 'forbidden'",
        caseSensitive: false,
      ).allMatches(p0Sql).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      p0Sql,
      contains(
        'revoke all on function public.get_ai_access_decision(uuid,text) from public, anon',
      ),
    );
  });

  test('applicants cannot select consultation admin_note', () {
    expect(
      p0Sql,
      contains(
        'revoke select, insert on table public.consultation_requests from authenticated',
      ),
    );
    final applicantSelect = RegExp(
      r'grant select\s*\(([^)]*)\)\s*on table public\.consultation_requests to authenticated',
      caseSensitive: false,
    ).firstMatch(p0Sql);
    expect(applicantSelect, isNotNull);
    expect(applicantSelect!.group(1), isNot(contains('admin_note')));
  });

  test('Storage update matches upsert and stays owner-folder scoped', () {
    final storage = read('lib/core/supabase/supabase_storage.dart');
    expect(storage, contains('upsert: true'));
    expect(alignmentSql, contains('for update'));
    expect(alignmentSql, contains("bucket_id = 'documents'"));
    expect(
      RegExp(
        r"\(storage\.foldername\(name\)\)\[1\] = \(select auth\.uid\(\)\)::text",
        caseSensitive: false,
      ).allMatches(alignmentSql).length,
      2,
      reason: 'UPDATE USING and WITH CHECK must both enforce owner folder',
    );
    expect(alignmentSql, isNot(contains('using (true)')));
    expect(alignmentSql, isNot(contains('with check (true)')));
  });

  test('consultation submission is RPC-only and rate limited', () {
    final page = read(
      'lib/features/consultation/presentation/pages/consultation_page.dart',
    );
    expect(page, contains("client.rpc("));
    expect(page, contains("'submit_consultation_request'"));
    expect(page, isNot(contains("from('consultation_requests').insert")));
    expect(
      alignmentSql,
      contains(
        'revoke insert on table public.consultation_requests from authenticated',
      ),
    );
    expect(alignmentSql, contains('pg_advisory_xact_lock'));
    expect(alignmentSql, contains('v_hour_count >= 3'));
    expect(alignmentSql, contains('v_day_count >= 10'));
    expect(
      alignmentSql,
      contains("raise exception 'consultation_rate_limited'"),
    );
  });

  test('existing upload and guest AI abuse bounds remain present', () {
    final storage = read('lib/core/supabase/supabase_storage.dart');
    final guest = read(
      'supabase/migrations/20261007210000_stage4_user_ai_quota_grounding.sql',
    );
    expect(storage, contains('static const maxBytes = 10 * 1024 * 1024'));
    expect(storage, contains("'application/pdf'"));
    expect(storage, contains("'image/jpeg'"));
    expect(storage, contains("'image/png'"));
    expect(
      guest,
      contains(
        "grant execute on function public.consume_ai_guest_quota(text, integer) to service_role",
      ),
    );
    expect(guest, contains('if v_count >= v_limit'));
    expect(guest, contains("'anonymous_quota_exceeded'"));
  });

  test('role escalation and human Feed publication guards remain intact', () {
    expect(p0Sql, contains('prevent_profile_role_escalation'));
    expect(p0Sql, contains("private.has_role(array['super_admin'])"));
    expect(p0Sql, contains('guard_human_feed_mutation'));
    expect(p0Sql, contains('rad.human_publish_actor'));
    expect(p0Sql, contains("v_draft.status <> 'approved'"));
  });
}
