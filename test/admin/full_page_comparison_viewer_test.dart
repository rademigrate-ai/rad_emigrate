import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/admin/domain/entities/admin_cms_entities.dart';
import 'package:rad_emigrate/features/admin/presentation/widgets/full_page_comparison_viewer.dart';
import 'package:rad_emigrate/features/admin/presentation/widgets/source_provenance_badge.dart';

void main() {
  group('FullPageComparisonViewer & Granular Editorial Review', () {
    final baseSections = [
      ArticleSectionInput(
        id: 'sec-1',
        anchor: 'eligibility',
        heading: 'شرایط پایه و الزامات عمومی',
        order: 1,
        blocks: [
          ContentBlock(
            id: 'b-1',
            type: 'paragraph',
            text: 'متقاضیان باید دارای مدرک زبان معتبر و تمکن مالی پایه باشند.',
            items: const [],
          ),
        ],
        evidenceRefs: const [],
      ),
      ArticleSectionInput(
        id: 'sec-2',
        anchor: 'financial',
        heading: 'هزینه‌ها و تمکن مالی الزامی',
        order: 2,
        blocks: [
          ContentBlock(
            id: 'b-2',
            type: 'paragraph',
            text: 'تمکن مالی سالانه معادل ۱۳,۷۵۷ دلار است.',
            items: const [],
          ),
        ],
        evidenceRefs: const [],
      ),
      ArticleSectionInput(
        id: 'sec-3',
        anchor: 'deprecated',
        heading: 'مقررات موقت دوران کرونا',
        order: 3,
        blocks: [
          ContentBlock(
            id: 'b-3',
            type: 'paragraph',
            text: 'ارائه تست منفی پی‌سی‌آر پیش از پرواز الزامی است.',
            items: const [],
          ),
        ],
        evidenceRefs: const [],
      ),
    ];

    final changes = [
      // Sec-2: Modified
      SectionChange(
        sectionId: 'sec-2',
        operation: 'replace',
        beforeHash: 'hash-sec-2-v1',
        replacement: ArticleSectionInput(
          id: 'sec-2',
          anchor: 'financial',
          heading: 'هزینه‌ها و تمکن مالی جدید مصوب ۲۰۲۴',
          order: 2,
          blocks: [
            ContentBlock(
              id: 'b-2-new',
              type: 'paragraph',
              text: 'طبق دستورالعمل جدید اداره مهاجرت، حداقل تمکن به ۲۰,۶۳۵ دلار افزایش یافت.',
              items: const [],
            ),
          ],
          evidenceRefs: const [],
        ),
        claimIds: ['claim-fee-1'],
      ),

      // Sec-3: Removed
      SectionChange(
        sectionId: 'sec-3',
        operation: 'remove',
        beforeHash: 'hash-sec-3-v1',
        replacement: null,
        claimIds: ['claim-deprecate-1'],
      ),

      // Sec-4: Added
      SectionChange(
        sectionId: 'sec-4',
        operation: 'add',
        beforeHash: null,
        replacement: ArticleSectionInput(
          id: 'sec-4',
          anchor: 'biometrics',
          heading: 'ثبت اطلاعات بیومتریک و انگشت‌نگاری',
          order: 4,
          blocks: [
            ContentBlock(
              id: 'b-4-new',
              type: 'paragraph',
              text: 'کلیه متقاضیان ملزم به انجام بیومتریک در مراکز VAC ظرف ۳۰ روز هستند.',
              items: const [],
            ),
          ],
          evidenceRefs: const [],
        ),
        claimIds: ['claim-bio-1'],
      ),
    ];

    final evidence = [
      EvidenceRef(
        sourceDocumentId: 'doc-ircc-2024',
        snapshotId: 'snap-1',
        sectionId: 'sec-2',
        url: 'https://www.canada.ca/en/immigration-refugees-citizenship/services/study-canada.html',
        publisher: 'IRCC Canada',
        sourceClass: 'official_primary',
        excerpt: 'Effective January 1, 2024, the cost-of-living requirement for a single study permit applicant is \$20,635.',
        fetchedAt: DateTime(2024, 1, 15),
        verifiedAt: DateTime(2024, 1, 15),
        verificationState: FactualStatus.verified,
        freshnessState: 'live',
      ),
    ];

    testWidgets(
      'renders complete page with unchanged, added, removed and modified sections in context',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FullPageComparisonViewer(
                  articleTitle: 'ویزای تحصیلی کانادا (Study Permit)',
                  countryFlag: '🇨🇦',
                  countryName: 'کانادا',
                  category: 'تحصیلی',
                  baseRevision: 2,
                  proposedRevision: 3,
                  baseSections: baseSections,
                  changes: changes,
                  evidence: evidence,
                ),
              ),
            ),
          ),
        );

        // Verify Title and Metadata
        expect(find.text('ویزای تحصیلی کانادا (Study Permit)'), findsOneWidget);
        expect(find.text('🇨🇦'), findsOneWidget);
        expect(find.textContaining('v2'), findsOneWidget);
        expect(find.textContaining('v3'), findsOneWidget);

        // 1. Unchanged Section (sec-1) is visible in full context
        expect(find.text('شرایط پایه و الزامات عمومی'), findsOneWidget);
        expect(find.text('[بدون تغییر]'), findsOneWidget);
        expect(
          find.text(
            'متقاضیان باید دارای مدرک زبان معتبر و تمکن مالی پایه باشند.',
          ),
          findsOneWidget,
        );

        // 2. Modified Section (sec-2) shows before and proposed
        expect(
          find.textContaining('هزینه‌ها و تمکن مالی جدید مصوب ۲۰۲۴'),
          findsOneWidget,
        );
        expect(find.text('[~] بخش اصلاح شده'), findsOneWidget);
        expect(
          find.text('تمکن مالی سالانه معادل ۱۳,۷۵۷ دلار است.'),
          findsOneWidget,
        );
        expect(
          find.text(
            'طبق دستورالعمل جدید اداره مهاجرت، حداقل تمکن به ۲۰,۶۳۵ دلار افزایش یافت.',
          ),
          findsOneWidget,
        );

        // 3. Removed Section (sec-3) shows removal indicator
        expect(find.text('مقررات موقت دوران کرونا'), findsOneWidget);
        expect(find.text('[-] بخش حذف شده'), findsOneWidget);

        // 4. Added Section (sec-4) shows addition indicator
        expect(find.text('ثبت اطلاعات بیومتریک و انگشت‌نگاری'), findsOneWidget);
        expect(find.text('[+] بخش جدید افزوده شده'), findsOneWidget);
      },
    );

    testWidgets(
      'allows section filter toggle between all, changed, and unchanged',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FullPageComparisonViewer(
                  articleTitle: 'ویزای تحصیلی کانادا',
                  baseRevision: 2,
                  proposedRevision: 3,
                  baseSections: baseSections,
                  changes: changes,
                  evidence: evidence,
                ),
              ),
            ),
          ),
        );

        // Click "Changed Only" filter chip
        await tester.tap(find.textContaining('تغییرات (3)'));
        await tester.pumpAndSettle();

        // Unchanged section should be filtered out
        expect(find.text('[بدون تغییر]'), findsNothing);
        expect(find.text('[+] بخش جدید افزوده شده'), findsOneWidget);
        expect(find.text('[~] بخش اصلاح شده'), findsOneWidget);

        // Click "Unchanged Only" filter chip
        await tester.tap(find.textContaining('بدون تغییر (1)'));
        await tester.pumpAndSettle();

        expect(find.text('[بدون تغییر]'), findsOneWidget);
        expect(find.text('[+] بخش جدید افزوده شده'), findsNothing);
      },
    );

    testWidgets(
      'triggers granular callbacks on Accept, Reject and Manual Edit actions',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        String? acceptedSectionId;
        String? rejectedSectionId;
        String? editedSectionId;
        String? editedText;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FullPageComparisonViewer(
                  articleTitle: 'ویزای تحصیلی کانادا',
                  baseRevision: 2,
                  proposedRevision: 3,
                  baseSections: baseSections,
                  changes: changes,
                  evidence: evidence,
                  onSectionAction: (secId, action) {
                    if (action == 'accept') acceptedSectionId = secId;
                    if (action == 'reject') rejectedSectionId = secId;
                  },
                  onSectionEdit: (secId, text) {
                    editedSectionId = secId;
                    editedText = text;
                  },
                ),
              ),
            ),
          ),
        );

        // Tap Accept on the added section
        final acceptButtons = find.text('تأیید این بند');
        expect(acceptButtons, findsWidgets);
        await tester.ensureVisible(acceptButtons.first);
        await tester.tap(acceptButtons.first);
        await tester.pumpAndSettle();
        expect(acceptedSectionId, isNotNull);

        // Tap Reject on the modified section
        final rejectButtons = find.text('رد این بند');
        expect(rejectButtons, findsWidgets);
        await tester.ensureVisible(rejectButtons.first);
        await tester.tap(rejectButtons.first);
        await tester.pumpAndSettle();
        expect(rejectedSectionId, isNotNull);

        // Tap Edit Text on a changed section
        final editButtons = find.text('ویرایش متن');
        expect(editButtons, findsWidgets);
        await tester.ensureVisible(editButtons.first);
        await tester.tap(editButtons.first);
        await tester.pumpAndSettle();

        // In-place text field should be present
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(
          find.byType(TextField),
          'متن ویرایش‌شده توسط مدیر محتوا.',
        );
        final saveEditButton = find.text('ثبت ویرایش');
        await tester.ensureVisible(saveEditButton);
        await tester.tap(saveEditButton);
        await tester.pumpAndSettle();

        expect(editedSectionId, isNotNull);
        expect(editedText, equals('متن ویرایش‌شده توسط مدیر محتوا.'));
      },
    );

    testWidgets('renders conflict warning banner when hasConflicts is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FullPageComparisonViewer(
                articleTitle: 'ویزای کار استرالیا',
                baseRevision: 1,
                proposedRevision: 2,
                hasConflicts: true,
                baseSections: baseSections,
                changes: changes,
                evidence: evidence,
              ),
            ),
          ),
        ),
      );

      expect(
        find.textContaining(
          'هشدار مغایرت: میان منابع رسمی استناد تناقض اطلاعاتی مشاهده شده است',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders SourceProvenanceBadge for all 5 trust states', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SourceProvenanceBadge(
                  trustLevel: SourceTrustLevel.officiallyVerified,
                ),
                SourceProvenanceBadge(
                  trustLevel: SourceTrustLevel.adminDefined,
                ),
                SourceProvenanceBadge(trustLevel: SourceTrustLevel.aiSuggested),
                SourceProvenanceBadge(trustLevel: SourceTrustLevel.conflicting),
                SourceProvenanceBadge(trustLevel: SourceTrustLevel.unverified),
              ],
            ),
          ),
        ),
      );

      expect(find.text('تأییدشده رسمی'), findsOneWidget);
      expect(
        find.text('وارد شده توسط مدیر · فاقد تأییدیه رسمی'),
        findsOneWidget,
      );
      expect(
        find.text('پیشنهاد هوش مصنوعی · در انتظار راستی‌آزمایی'),
        findsOneWidget,
      );
      expect(find.text('دارای تناقض در مراجع'), findsOneWidget);
      expect(find.text('در انتظار راستی‌آزمایی'), findsOneWidget);
    });

    testWidgets('handles 200% text scale without overflow exceptions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: FullPageComparisonViewer(
                  articleTitle: 'ویزای تحصیلی کانادا',
                  baseRevision: 2,
                  proposedRevision: 3,
                  baseSections: baseSections,
                  changes: changes,
                  evidence: evidence,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
