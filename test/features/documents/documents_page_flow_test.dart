import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/core/widgets/empty_state.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document_type.dart';
import 'package:rad_emigrate/features/documents/domain/repositories/document_repository.dart';
import 'package:rad_emigrate/features/documents/presentation/pages/documents_page.dart';
import 'package:rad_emigrate/features/documents/presentation/providers/document_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _FakeDocRepo implements DocumentRepository {
  _FakeDocRepo(this.docs);
  List<Document> docs;
  int upsertCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<Document>> listDocuments({String? userId}) async => docs;

  @override
  Future<Document?> getDocument(String id) async {
    for (final d in docs) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Future<Document> upsertDocument(Document document) async {
    upsertCalls++;
    final existingIdx = docs.indexWhere((d) => d.id == document.id);
    if (existingIdx != -1) {
      docs[existingIdx] = document;
      return document;
    }
    final created = document.id.isEmpty
        ? document.copyWith(id: 'doc-${docs.length + 1}')
        : document;
    docs = [created, ...docs];
    return created;
  }

  @override
  Future<void> deleteDocument(Document document) async {
    deleteCalls++;
    docs.removeWhere((d) => d.id == document.id);
  }

  @override
  Future<Uri> previewDocument(Document document) async =>
      Uri.parse('https://signed.example.com/preview/${document.id}');

  @override
  Future<Document> uploadDocument({
    required Document document,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final updated = document.copyWith(
      name: fileName,
      status: DocumentVerificationStatus.uploaded,
      storagePath: 'user-id/${document.id}/$fileName',
    );
    return upsertDocument(updated);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testDoc1 = Document(
    id: 'doc-pass-1',
    typeId: 'passport',
    name: 'National Passport',
    kind: DocumentTypeKind.passport,
    status: DocumentVerificationStatus.verified,
    storagePath: 'user-id/doc-pass-1/passport.pdf',
    updatedAt: DateTime(2026, 10, 18),
  );

  final testDoc2 = Document(
    id: 'doc-bank-2',
    typeId: 'financial',
    name: 'Bank Statement 6 Months',
    kind: DocumentTypeKind.financial,
    status: DocumentVerificationStatus.missing,
    updatedAt: DateTime(2026, 10, 17),
  );

  Widget createSubject({
    required SharedPreferences prefs,
    required _FakeDocRepo repo,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        documentControllerProvider.overrideWith(
          (ref) => DocumentController(repo, 'test-user-id'),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const DocumentsPage(),
      ),
    );
  }

  testWidgets(
    'DocumentsPage lists documents with status badges and filter chips',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      final repo = _FakeDocRepo([testDoc1, testDoc2]);

      await tester.pumpWidget(createSubject(prefs: prefs, repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('National Passport'), findsOneWidget);
      expect(find.text('Bank Statement 6 Months'), findsOneWidget);

      // Filter by Passport kind chip
      final passportChip = find.widgetWithText(ChoiceChip, 'Passport');
      expect(passportChip, findsOneWidget);
      await tester.tap(passportChip);
      await tester.pumpAndSettle();

      expect(find.text('National Passport'), findsOneWidget);
      expect(find.text('Bank Statement 6 Months'), findsNothing);

      // Filter by Financial kind chip ('Financial document')
      final financialChip = find.widgetWithText(
        ChoiceChip,
        'Financial document',
      );
      expect(financialChip, findsOneWidget);
      await tester.tap(financialChip);
      await tester.pumpAndSettle();

      expect(find.text('Bank Statement 6 Months'), findsOneWidget);
      expect(find.text('National Passport'), findsNothing);
    },
  );

  testWidgets('tapping document opens bottom sheet with details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final repo = _FakeDocRepo([testDoc1]);

    await tester.pumpWidget(createSubject(prefs: prefs, repo: repo));
    await tester.pumpAndSettle();

    // Tap the document tile
    await tester.tap(find.text('National Passport'));
    await tester.pumpAndSettle();

    // Bottom sheet is displayed
    expect(find.text('Type: Passport'), findsOneWidget);
    expect(find.text('Status: Verified'), findsOneWidget);
  });

  testWidgets('empty state renders EmptyState widget when no documents exist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final repo = _FakeDocRepo([]);

    await tester.pumpWidget(createSubject(prefs: prefs, repo: repo));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No documents uploaded yet'), findsOneWidget);
  });

  testWidgets('Add type button invokes addDocumentType on controller', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final repo = _FakeDocRepo([testDoc1]);

    await tester.pumpWidget(createSubject(prefs: prefs, repo: repo));
    await tester.pumpAndSettle();

    final addTypeBtn = find.widgetWithText(FilledButton, 'Add type');
    expect(addTypeBtn, findsOneWidget);
    await tester.tap(addTypeBtn);
    await tester.pumpAndSettle();

    expect(repo.upsertCalls, 1);
    expect(find.text('New document'), findsOneWidget);
  });
}
