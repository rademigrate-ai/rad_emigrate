import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/admin/data/admin_cms_repository.dart';
import 'package:rad_emigrate/features/admin/data/research_review_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/mock_supabase_service.dart';

void main() {
  test(
    'structured review selects versioned context and safe save RPC',
    () async {
      final paths = <String>[];
      final context = <String, dynamic>{
        'proposal': {'id': 'proposal', 'revision': 1},
        'base': {
          'revision_id': 'base',
          'content_hash': 'hash',
          'body': {'sections': []},
          'rich_sections': [],
        },
        'review_revision': 0,
        'stale': false,
        'decisions': [],
        'structured_patches': [],
        'base_rich_hash': 'hash',
      };
      final service = await mockSupabaseService((r) async {
        paths.add(r.url.path);
        if (r.url.path.endsWith('/save_structured_research_review')) {
          return rpcJson({
            'data': {
              'published': false,
              'draft_revision': null,
              'review_revision': 1,
            },
          });
        }
        return rpcJson({'data': context});
      });
      final repository = ResearchReviewRepository(service);
      final loaded = await repository.context('proposal');
      await repository.save(
        context: loaded,
        mode: 'save_review',
        decisions: {},
        edits: {},
        note: '',
      );
      expect(paths[0], endsWith('/get_research_review_context_v2'));
      expect(paths[1], endsWith('/save_structured_research_review'));
    },
  );
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
  test(
    'employer approval creates only a server-bound unpublished CMS draft',
    () async {
      final calls = <String>[];
      final requests = <Map<String, dynamic>>[];
      final service = await mockSupabaseService((r) async {
        calls.add(r.url.path);
        requests.add(
          (jsonDecode(r.body) as Map)['p_request'] as Map<String, dynamic>,
        );
        return rpcJson({
          'data': {
            'published': false,
            'draft_revision': {
              'article_id': 'target-article',
              'editorial_state': 'draft',
            },
          },
        });
      });
      final repo = ResearchReviewRepository(service);
      final review = {
        'proposal': {
          'id': 'proposal',
          'revision': 7,
          'target_article_id': 'target-article',
        },
        'base': {
          'revision_id': 'current-base-revision',
          'content_hash': 'current-base-hash',
        },
        'review_revision': 5,
        'stale': false,
        'structured_patches': [
          {'id': 'changed-block'},
        ],
      };
      final result = await repo.save(
        context: review,
        mode: 'create_draft',
        decisions: {'changed-block': 'accepted'},
        edits: {'changed-block': 'Evidence-supported edit'},
        note: 'Human-reviewed source evidence',
      );
      expect(result['published'], false);
      expect(result['draft_revision']['article_id'], 'target-article');
      expect(calls, [endsWith('/save_structured_research_review')]);
      expect(requests.single['mode'], 'create_draft');
      expect(requests.single['base_revision_id'], 'current-base-revision');
      expect(requests.single['base_content_hash'], 'current-base-hash');
      expect(requests.single['decisions'], [
        {
          'section_id': 'changed-block',
          'decision': 'edit',
          'edited_text': 'Evidence-supported edit',
        },
      ]);
      expect(calls.any((path) => path.contains('publish')), isFalse);
      expect(calls.any((path) => path.contains('feed')), isFalse);
    },
  );

  test(
    'conflicting CMS target or stale base cannot be called approved',
    () async {
      final service = await mockSupabaseService(
        (r) async => rpcJson({
          'data': {
            'published': false,
            'draft_revision': {
              'article_id': 'different-article',
              'editorial_state': 'draft',
            },
          },
        }),
      );
      final repo = ResearchReviewRepository(service);
      final review = {
        'proposal': {
          'id': 'proposal',
          'revision': 2,
          'target_article_id': 'expected-article',
        },
        'base': {'revision_id': 'base', 'content_hash': 'hash'},
        'review_revision': 1,
        'stale': false,
        'structured_patches': [],
      };
      await expectLater(
        repo.save(
          context: review,
          mode: 'create_draft',
          decisions: {},
          edits: {},
          note: '',
        ),
        throwsA(isA<CmsException>().having((e) => e.code, 'code', 'malformed')),
      );
      await expectLater(
        repo.save(
          context: {...review, 'stale': true},
          mode: 'create_draft',
          decisions: {},
          edits: {},
          note: '',
        ),
        throwsA(isA<CmsException>().having((e) => e.code, 'code', 'conflict')),
      );
    },
  );

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
