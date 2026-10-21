import 'package:rad_emigrate/features/profile/domain/curated_rules_gate.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rad_emigrate/core/network/api_exception.dart';
import 'package:rad_emigrate/core/supabase/supabase_client.dart';
import 'package:rad_emigrate/core/supabase/supabase_providers.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/documents/data/datasources/document_local_datasource.dart';
import 'package:rad_emigrate/features/documents/data/datasources/document_remote_datasource.dart';
import 'package:rad_emigrate/features/documents/data/repositories/document_repository_impl.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document.dart';
import 'package:rad_emigrate/features/documents/domain/repositories/document_repository.dart';
import 'package:rad_emigrate/features/documents/presentation/providers/document_controller.dart';
import 'package:rad_emigrate/features/applications/domain/entities/application_status.dart';
import 'package:rad_emigrate/features/applications/domain/entities/visa_application.dart';
import 'package:rad_emigrate/features/applications/domain/repositories/application_repository.dart';
import 'package:rad_emigrate/features/applications/presentation/providers/application_controller.dart';
import 'package:rad_emigrate/features/profile/domain/entities/user_profile.dart';
import 'package:rad_emigrate/features/profile/domain/entities/profile_entity.dart';
import 'package:rad_emigrate/features/profile/domain/repositories/profile_repository.dart';
import 'package:rad_emigrate/features/profile/domain/repositories/immigration_profile_repository.dart';
import 'package:rad_emigrate/features/profile/domain/immigration_profile_validator.dart';
import 'package:rad_emigrate/features/profile/domain/pathway_assessment.dart';
import 'package:rad_emigrate/features/profile/presentation/providers/profile_controller.dart';
import 'package:rad_emigrate/features/profile/presentation/providers/immigration_profile_controller.dart';

const a = 'a1111111-1111-4111-8111-111111111111';
const b = 'b1111111-1111-4111-8111-111111111111';
Document doc(String owner) => Document(
  id: 'doc',
  typeId: 'passport',
  name: 'PRIVATE_$owner',
  status: DocumentVerificationStatus.uploaded,
  userId: owner,
  storagePath: '$owner/doc/file.pdf',
);
VisaApplication app(String owner) => VisaApplication(
  id: 'case',
  title: 'PRIVATE_$owner',
  programName: 'synthetic',
  country: 'ZZ',
  status: ApplicationStatus.draft,
  updatedAt: DateTime.utc(2026),
  userId: owner,
);
ImmigrationProfile immigration(String owner) => const ImmigrationProfile()
    .provide(ImmigrationProfileField.fullName, value: 'PRIVATE_$owner');

class _Pending<T> {
  final values = <String, List<Completer<T>>>{};
  Future<T> request(String id) {
    final c = Completer<T>();
    (values[id] ??= []).add(c);
    return c.future;
  }

  void complete(String id, T value) {
    for (final c in values[id] ?? <Completer<T>>[]) {
      if (!c.isCompleted) c.complete(value);
    }
  }
}

class _Auth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Service implements SupabaseClientService {
  _Service(this.client);
  @override
  final SupabaseClient client;
  @override
  bool get isInitialized => true;
  @override
  Object? initializationError;
  @override
  Future<bool> initialize() async => true;
}

Future<void> activate(SupabaseClient client, String owner) async {
  String encode(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final token =
      '${encode({'alg': 'none'})}.${encode({'sub': owner, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.synthetic';
  await client.auth.recoverSession(
    jsonEncode({
      'access_token': token,
      'refresh_token': 'synthetic-only',
      'expires_in': 3600,
      'token_type': 'bearer',
      'user': {
        'id': owner,
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-01-01T00:00:00Z',
      },
    }),
  );
}

class _Docs implements DocumentRepository {
  final pending = _Pending<List<Document>>();
  final preview = Completer<Uri>();
  @override
  Future<List<Document>> listDocuments({String? userId}) =>
      pending.request(userId!);
  @override
  Future<Uri> previewDocument(Document document) => preview.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Apps implements ApplicationRepository {
  final pending = _Pending<List<VisaApplication>>();
  @override
  Future<List<VisaApplication>> listApplications({String? userId}) =>
      pending.request(userId!);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profiles implements ProfileRepository {
  final pending = _Pending<UserProfile?>();
  @override
  Future<UserProfile?> getProfile(String userId) => pending.request(userId);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Immigration implements ImmigrationProfileRepository {
  final pending = _Pending<ImmigrationProfile?>();
  List<PathwayEligibilityRule>? assessedRules;
  @override
  Future<ImmigrationProfile?> getImmigrationProfile(String userId) =>
      userId == 'guest' ? Future.value(null) : pending.request(userId);
  @override
  ImmigrationProfileValidationResult validate(ImmigrationProfile profile) =>
      ImmigrationProfileValidator.validate(profile);
  @override
  PathwayAssessmentResult assessPathway({
    required ImmigrationProfile profile,
    required String programId,
    required List<PathwayEligibilityRule> rules,
    DateTime? now,
  }) {
    assessedRules = rules;
    return const PathwayAssessmentService().assess(
      profile: profile,
      programId: programId,
      rules: rules,
      now: now,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Unavailable extends DocumentRemoteDataSource {
  _Unavailable() : super(SupabaseClientService.instance);
  @override
  Future<List<Document>> list({String? userId}) async =>
      throw const ApiException(message: 'synthetic unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'document metadata partitions A and B and rejects wrong-owner scoped rows',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final cache = DocumentLocalDataSource(prefs);
      await cache.writeAll([doc(a), doc(b)], userId: a);
      expect((await cache.readAll(userId: a)).single.userId, a);
      expect(await cache.readAll(userId: b), isEmpty);
      await prefs.setString(
        DocumentLocalDataSource.keyFor(b),
        jsonEncode([doc(a).toJson()]),
      );
      expect(await cache.readAll(userId: b), isEmpty);
      expect((await cache.readAll(userId: a)).single.userId, a);
    },
  );
  test(
    'unscoped legacy document metadata never hydrates A guest or B',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rad_documents', jsonEncode([doc(a).toJson()]));
      final cache = DocumentLocalDataSource(prefs);
      expect(await cache.readAll(userId: b), isEmpty);
      expect(await cache.readAll(userId: ''), isEmpty);
      expect(await cache.readAll(userId: a), isEmpty);
      expect(prefs.getString('rad_documents'), isNull);
    },
  );
  test(
    'actual document repository offline fallback cannot return another owner',
    () async {
      final cache = DocumentLocalDataSource(
        await SharedPreferences.getInstance(),
      );
      await cache.writeAll([doc(a)], userId: a);
      final repo = DocumentRepositoryImpl(remote: _Unavailable(), local: cache);
      expect(await repo.listDocuments(userId: b), isEmpty);
      expect(await repo.listDocuments(), isEmpty);
      expect((await repo.listDocuments(userId: a)).single.userId, a);
    },
  );
  test('late signed preview is rejected after identity changes', () async {
    var identity = a;
    final repo = _Docs();
    final controller = DocumentController(
      repo,
      a,
      isCurrent: () => identity == a,
    );
    addTearDown(controller.dispose);
    repo.pending.complete(a, [doc(a)]);
    await Future<void>.delayed(Duration.zero);
    final future = controller.previewDocument('doc');
    identity = b;
    repo.preview.complete(
      Uri.parse('https://storage.example/private?token=synthetic'),
    );
    await expectLater(future, throwsStateError);
  });
  test('SDK A logout B clears all private selectors despite stale auth mirror and late A replies', () async {
    final client = SupabaseClient(
      'http://127.0.0.1:59999',
      'synthetic-only',
      httpClient: MockClient(
        (r) async => http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        ),
      ),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    await activate(client, a);
    final auth = AuthController(_Auth())
      ..applySession(
        const UserSession(
          userId: a,
          authenticated: true,
          token: 'synthetic-only',
          fullName: 'PRIVATE_A',
        ),
      );
    final docs = _Docs(),
        apps = _Apps(),
        profiles = _Profiles(),
        immig = _Immigration();
    final container = ProviderContainer(
      overrides: [
        supabaseClientServiceProvider.overrideWithValue(_Service(client)),
        authControllerProvider.overrideWith((ref) => auth),
        documentRepositoryProvider.overrideWithValue(docs),
        applicationRepositoryProvider.overrideWithValue(apps),
        profileRepositoryProvider.overrideWithValue(profiles),
        immigrationProfileRepositoryProvider.overrideWithValue(immig),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(supabaseAuthUserIdProvider.future);
    container.listen(documentControllerProvider, (_, _) {});
    container.listen(applicationControllerProvider, (_, _) {});
    container.listen(profileControllerProvider, (_, _) {});
    container.listen(immigrationProfileControllerProvider, (_, _) {});
    await client.auth.signOut(scope: SignOutScope.local);
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(auth.current.userId, a);
    expect(container.read(verifiedUserSessionProvider), isNull);
    expect(container.read(documentControllerProvider).valueOrNull, isEmpty);
    expect(container.read(applicationControllerProvider).valueOrNull, isEmpty);
    expect(container.read(profileControllerProvider).valueOrNull, isNull);
    await activate(client, b);
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    docs.pending.complete(a, [doc(a)]);
    apps.pending.complete(a, [app(a)]);
    profiles.pending.complete(
      a,
      const UserProfile(id: a, firstName: 'PRIVATE_A'),
    );
    immig.pending.complete(a, immigration(a));
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(container.read(documentControllerProvider).valueOrNull, isNull);
    expect(container.read(applicationControllerProvider).valueOrNull, isNull);
    expect(container.read(profileControllerProvider).valueOrNull, isNull);
    expect(
      jsonEncode(
        container.read(immigrationProfileControllerProvider).profile.toJson(),
      ),
      isNot(contains('PRIVATE_$a')),
    );
    docs.pending.complete(b, [doc(b)]);
    apps.pending.complete(b, [app(b)]);
    profiles.pending.complete(
      b,
      const UserProfile(id: b, firstName: 'PRIVATE_B'),
    );
    immig.pending.complete(b, immigration(b));
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(
      container.read(documentControllerProvider).valueOrNull!.single.userId,
      b,
    );
    expect(
      container.read(applicationControllerProvider).valueOrNull!.single.userId,
      b,
    );
    expect(container.read(profileControllerProvider).valueOrNull!.id, b);
    expect(
      jsonEncode(
        container.read(immigrationProfileControllerProvider).profile.toJson(),
      ),
      contains('PRIVATE_$b'),
    );
    expect(container.read(verifiedUserSessionProvider), isNull);
  });
  test('runtime default has no invented approval or eligibility rules and direct assessment is gated', () async {
    expect(defaultCuratedRulePackage.editorialApproved, isFalse);
    expect(defaultCuratedRulePackage.approvedAt, isNull);
    expect(defaultCuratedRulePackage.approverLabel, isNull);
    expect(curatedPathwayRules, isEmpty);
    final repo = _Immigration();
    final controller = ImmigrationProfileController(repo, a);
    addTearDown(controller.dispose);
    controller.assessPathway('express-entry');
    expect(repo.assessedRules, isEmpty);
    repo.pending.complete(a, null);
    await Future<void>.delayed(Duration.zero);
  });
  test(
    'an approval flag without an approval date cannot activate a rule package',
    () {
      final rule = PathwayEligibilityRule(
        id: 'synthetic',
        programId: 'synthetic',
        jurisdiction: 'ZZ',
        requiredFields: const {},
        evidence: PathwayRuleEvidence(
          jurisdiction: 'ZZ',
          title: 'SYNTHETIC',
          sourceUrl: 'https://example.gov/synthetic',
          retrievedAt: DateTime.utc(2026),
          publisher: 'SYNTHETIC',
        ),
      );
      final undated = CuratedRulePackage(
        packageId: 'synthetic',
        rules: [rule],
        editorialApproved: true,
        approvedAt: null,
      );
      expect(const CuratedRulesGate().loadApproved(undated), isEmpty);
      final dated = CuratedRulePackage(
        packageId: 'synthetic',
        rules: [rule],
        editorialApproved: true,
        approvedAt: DateTime.utc(2026),
      );
      expect(const CuratedRulesGate().loadApproved(dated), [rule]);
    },
  );
}
