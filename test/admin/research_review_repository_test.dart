import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/admin/data/admin_cms_repository.dart';
import 'package:rad_emigrate/features/admin/data/research_review_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/mock_supabase_service.dart';

void main() {
  final context = <String, dynamic>{
    'proposal': {'id': 'proposal', 'revision': 1},
    'base': {
      'revision_id': 'base',
      'content_hash': 'hash',
      'body': {'sections': []},
    },
    'review_revision': 0,
    'stale': false,
    'decisions': [],
  };
  test('review retries retain UUID and transmit granular edits', () async {
    final requests = <Map<String, dynamic>>[];
    final service = await mockSupabaseService((r) async {
      requests.add(
        (jsonDecode(r.body) as Map)['p_request'] as Map<String, dynamic>,
      );
      return rpcJson({
        'data': {'published': false},
      });
    });
    final repository = ResearchReviewRepository(service);
    Future<void> save(String text) async => repository.save(
      context: context,
      mode: 'save_review',
      decisions: {'one': 'accepted', 'two': 'rejected'},
      edits: {'one': text},
      note: 'Synthetic review',
    );
    await save('Synthetic edited paragraph');
    await save('Synthetic edited paragraph');
    await save('Different review');
    expect(
      requests[0]['request_key'],
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(requests[0], requests[1]);
    expect(requests[2]['request_key'], isNot(requests[0]['request_key']));
    expect(requests[0]['decisions'], [
      {
        'section_id': 'one',
        'decision': 'edit',
        'edited_text': 'Synthetic edited paragraph',
      },
      {'section_id': 'two', 'decision': 'reject', 'edited_text': null},
    ]);
    expect(requests[0].containsKey('sections'), isFalse);
  });
  test('late private response cannot survive logout', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final service = await mockSupabaseService((r) async {
      if (r.url.path.contains('/rpc/')) {
        started.complete();
        await release.future;
        return rpcJson({'data': context});
      }
      return rpcJson({});
    });
    final repository = ResearchReviewRepository(service);
    final pending = repository.context('proposal');
    final check = expectLater(
      pending,
      throwsA(
        isA<CmsException>().having((e) => e.code, 'code', 'unauthorized'),
      ),
    );
    await started.future;
    await service.client.auth.signOut(scope: SignOutScope.local);
    release.complete();
    await check;
    await expectLater(
      repository.context('proposal'),
      throwsA(isA<CmsException>()),
    );
  });
  test('malformed baseline never becomes an invented article', () async {
    final service = await mockSupabaseService(
      (r) async => rpcJson({
        'data': {
          'proposal': {'id': 'proposal'},
        },
      }),
    );
    await expectLater(
      ResearchReviewRepository(service).context('proposal'),
      throwsA(isA<CmsException>().having((e) => e.code, 'code', 'malformed')),
    );
  });
  test('server details are mapped to safe review conflict', () async {
    final service = await mockSupabaseService(
      (r) async =>
          rpcJson({'code': 'PT409', 'message': 'private upstream detail'}, 409),
    );
    await expectLater(
      ResearchReviewRepository(service).context('proposal'),
      throwsA(isA<CmsException>().having((e) => e.code, 'code', 'conflict')),
    );
  });
}
