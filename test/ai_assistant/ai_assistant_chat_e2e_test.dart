import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/app/dependencies.dart';
import 'package:rad_emigrate/core/services/ai/ai_request.dart';
import 'package:rad_emigrate/core/services/ai/ai_response.dart';
import 'package:rad_emigrate/core/services/ai/ai_service.dart';
import 'package:rad_emigrate/features/ai_assistant/data/ai_session_repository.dart';
import 'package:rad_emigrate/features/ai_assistant/domain/entities/ai_user_profile.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/pages/ai_assistant_page.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/widgets/ai_adviser_handoff_card.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/widgets/ai_citation_card.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/widgets/ai_document_chip.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/widgets/ai_history_drawer.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/widgets/ai_immigration_profile_sheet.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/widgets/ai_interactive_report_view.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/widgets/ai_markdown_view.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/widgets/ai_search_progress_card.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAiService implements AiService {
  final List<AiRequest> requests = [];
  String nextResponseText = 'پاسخ آزمایشی هوش مصنوعی راد';
  List<AiSource>? nextSources;
  bool isUncertain = false;

  @override
  bool get isAvailable => true;

  @override
  Future<String> ask(String prompt) async => nextResponseText;

  @override
  Future<AiResponse> complete(AiRequest request) async {
    requests.add(request);
    return AiResponse(
      text: nextResponseText,
      sources: nextSources ??
          const [
            AiSource(
              title: 'اداره مهاجرت استرالیا',
              url: 'https://homeaffairs.gov.au/visas/skilled',
              authority: 'Department of Home Affairs',
            ),
          ],
      uncertain: isUncertain,
    );
  }
}

class _FakeAiSessionRepository implements AiSessionRepository {
  final List<AiSession> sessions = [];
  final List<AiSessionMessage> messages = [];

  @override
  Future<List<AiSession>> listSessions(
    String userId, {
    String scope = 'user',
  }) async {
    return [
      AiSession(
        id: 'session-1',
        userId: userId,
        questionCount: 3,
        createdAt: DateTime(2026, 10, 20),
      ),
      AiSession(
        id: 'session-2',
        userId: userId,
        questionCount: 1,
        createdAt: DateTime(2026, 10, 25),
      ),
    ];
  }

  @override
  Future<AiSession> createSession(
    String userId, {
    String scope = 'user',
  }) async {
    final s = AiSession(
      id: 'session-${sessions.length + 1}',
      userId: userId,
      questionCount: 0,
      createdAt: DateTime.now(),
    );
    sessions.add(s);
    return s;
  }

  @override
  Future<List<AiSessionMessage>> history(String sessionId) async {
    return messages;
  }

  @override
  Future<void> saveMessage({
    required String sessionId,
    required String userId,
    required String role,
    required String content,
  }) async {
    messages.add(
      AiSessionMessage(
        id: 'msg-${messages.length + 1}',
        sessionId: sessionId,
        role: role,
        content: content,
        createdAt: DateTime.now(),
      ),
    );
  }
}

Widget _buildTestApp({
  required Widget child,
  _FakeAiService? aiService,
  _FakeAiSessionRepository? sessionRepository,
  Size surfaceSize = const Size(390, 844),
}) {
  return ProviderScope(
    overrides: [
      aiServiceProvider.overrideWithValue(aiService ?? _FakeAiService()),
      aiSessionRepositoryProvider.overrideWithValue(
        sessionRepository ?? _FakeAiSessionRepository(),
      ),
      authControllerProvider.overrideWith(
        (ref) => AuthController(_FakeAuthRepository())
          ..applySession(
            const UserSession(userId: 'test-user-123', authenticated: true),
          ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('fa'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: surfaceSize,
          disableAnimations: true,
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RAD User AI Assistant — Empty State & Quick Prompts', () {
    testWidgets('renders empty state with 5 quick prompts in Persian RTL', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildTestApp(
          surfaceSize: const Size(800, 1400),
          child: const AiAssistantPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify empty state welcome heading
      expect(find.text('دستیار هوشمند مهاجرت و عمومی راد'), findsOneWidget);

      // Verify all 5 quick shortcuts are present
      expect(find.text('سوال عمومی و روزمره'), findsOneWidget);
      expect(find.text('راهنمای ویزا و مهاجرت'), findsOneWidget);
      expect(find.text('جستجو در اینترنت و وب زنده'), findsOneWidget);
      expect(find.text('بررسی و تحلیل مدارک'), findsOneWidget);
      expect(find.text('مقایسه مقاصد مهاجرت'), findsOneWidget);

      // Tapping a quick shortcut sends the prompt directly
      await tester.tap(find.text('راهنمای ویزا و مهاجرت'));
      await tester.pumpAndSettle();

      // Verify the user question appears in the message stream
      expect(
        find.text('شرایط اخذ ویزای کاری آلمان (بلوکارت و کارت شانس) چیست؟'),
        findsOneWidget,
      );
    });
  });

  group('RAD User AI Assistant — Strict Zero Voice Safety Audit', () {
    testWidgets('strictly zero microphone, speech-to-text, or voice buttons exist in UI', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const AiAssistantPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Strict safety audit: No microphone or audio icons anywhere in the widget tree
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byIcon(Icons.mic_none), findsNothing);
      expect(find.byIcon(Icons.mic_off), findsNothing);
      expect(find.byIcon(Icons.record_voice_over), findsNothing);
      expect(find.byIcon(Icons.voice_chat), findsNothing);
      expect(find.byIcon(Icons.volume_up), findsNothing);
      expect(find.byIcon(Icons.hearing), findsNothing);
    });
  });

  group('RAD User AI Assistant — Web Search Mode & Multiline Composer', () {
    testWidgets('web search button toggles between auto, alwaysOn, and off', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const AiAssistantPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state is auto search
      expect(find.text('وب: خودکار'), findsOneWidget);

      // Tap once -> switch to alwaysOn
      await tester.tap(find.text('وب: خودکار'));
      await tester.pumpAndSettle();
      expect(find.text('وب: روشن'), findsOneWidget);

      // Tap second time -> switch to off
      await tester.tap(find.text('وب: روشن'));
      await tester.pumpAndSettle();
      expect(find.text('وب: خاموش'), findsOneWidget);

      // Tap third time -> return to auto
      await tester.tap(find.text('وب: خاموش'));
      await tester.pumpAndSettle();
      expect(find.text('وب: خودکار'), findsOneWidget);
    });

    testWidgets('composer accepts multiline text and send button is present', (
      tester,
    ) async {
      final fakeAi = _FakeAiService();
      await tester.pumpWidget(
        _buildTestApp(
          child: const AiAssistantPage(),
          aiService: fakeAi,
        ),
      );
      await tester.pumpAndSettle();

      final composerFinder = find.byType(TextField);
      expect(composerFinder, findsOneWidget);

      // Enter a question
      await tester.enterText(composerFinder, 'شرایط پذیرش تحصیلی چیست؟');
      await tester.pumpAndSettle();

      // Verify send button
      final sendBtnFinder = find.byIcon(Icons.send);
      expect(sendBtnFinder, findsOneWidget);

      await tester.tap(sendBtnFinder);
      await tester.pumpAndSettle();

      // Ai completed the request
      expect(fakeAi.requests, hasLength(1));
      expect(fakeAi.requests.first.prompt, contains('شرایط پذیرش تحصیلی چیست؟'));
    });
  });

  group('RAD User AI Assistant — Voluntary Immigration Profile Sheet', () {
    testWidgets('opens profile sheet, allows editing, and saves', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const AiAssistantPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the immigration profile button in AppBar
      final profileBtn = find.byTooltip('پروفایل مهاجرتی');
      expect(profileBtn, findsOneWidget);
      await tester.tap(profileBtn);
      await tester.pumpAndSettle();

      // Verify bottom sheet title and fields
      expect(find.text('پروفایل مهاجرتی اختیاری'), findsOneWidget);
      expect(find.text('آخرین مقطع تحصیلی و رشته'), findsOneWidget);
      expect(find.text('سابقه کار مرتبط (سال)'), findsOneWidget);
      expect(find.text('مدرک و نمره زبان'), findsOneWidget);
      expect(find.text('کشور هدف مورد نظر'), findsOneWidget);
      expect(find.text('تمکن مالی تقریبی'), findsOneWidget);

      // Verify toggle for AI reuse
      expect(find.text('شخصی‌سازی خودکار پاسخ‌های هوش مصنوعی'), findsOneWidget);

      // Tap save
      final saveBtn = find.text('ذخیره تنظیمات');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Bottom sheet closed
      expect(find.text('پروفایل مهاجرتی اختیاری'), findsNothing);
    });
  });

  group('RAD User AI Assistant — Rich Components', () {
    testWidgets('AiMarkdownView renders native table and copy code button', (
      tester,
    ) async {
      const markdownContent = '''
### جدول مقایسه ویزا
| کشور | نوع ویزا | حداقل بودجه |
|---|---|---|
| آلمان | کارت فرصت | ۱۲,۰۰۰ یورو |
| کانادا | استادی پرمیت | ۲۰,۶۳۵ دلار کانادا |

```python
def check_eligibility(points):
    return points >= 67
```
''';

      await tester.pumpWidget(
        _buildTestApp(
          child: const Scaffold(
            body: SingleChildScrollView(
              child: AiMarkdownView(content: markdownContent),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify headings and table contents
      expect(find.text('جدول مقایسه ویزا'), findsOneWidget);
      expect(find.text('کارت فرصت'), findsOneWidget);
      expect(find.text('استادی پرمیت'), findsOneWidget);

      // Verify code block copy button
      expect(find.text('کپی'), findsOneWidget);
    });

    testWidgets('AiInteractiveReportView renders checklist items and toggle updates state', (
      tester,
    ) async {
      final items = [
        ChecklistItemData(
          title: 'ارائه مدرک زبان آیلتس ۶.۵',
          description: 'حداقل نمره ۶ در هر مهارت',
          tier: RequirementTier.mandatory,
          isCompleted: false,
        ),
        ChecklistItemData(
          title: 'ارائه گواهی عدم سوء پیشینه',
          description: 'صادر شده در ۳ ماه اخیر',
          tier: RequirementTier.recommended,
          isCompleted: true,
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          child: Scaffold(
            body: AiInteractiveReportView(
              title: 'چک‌لیست مدارک ویزا',
              items: items,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('چک‌لیست مدارک ویزا'), findsOneWidget);
      expect(find.text('ارائه مدرک زبان آیلتس ۶.۵'), findsOneWidget);
      expect(find.text('الزامی'), findsOneWidget);
      expect(find.text('پیشنهادی'), findsOneWidget);

      // Toggle first item
      final checkboxFinder = find.byType(Checkbox).first;
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      expect(items.first.isCompleted, isTrue);
    });

    testWidgets('AiSearchProgressCard renders search query and live status', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const Scaffold(
            body: AiSearchProgressCard(
              query: 'قوانین ویزای استرالیا ۲۰۲۶',
              isSearching: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('نتایج جستجوی زنده در پاسخ لحاظ شد'), findsOneWidget);
      expect(find.text('عبارت جستجو: قوانین ویزای استرالیا ۲۰۲۶'), findsOneWidget);
    });

    testWidgets('AiDocumentChip displays file attachment and delete callback', (
      tester,
    ) async {
      var deleted = false;
      final doc = AiDocumentAttachment(
        name: 'passport_scan.pdf',
        sizeBytes: 1024 * 500,
        extension: 'pdf',
        status: DocumentProcessingStatus.selected,
      );

      await tester.pumpWidget(
        _buildTestApp(
          child: Scaffold(
            body: AiDocumentChip(
              attachment: doc,
              onRemove: () => deleted = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('passport_scan.pdf'), findsOneWidget);
      expect(find.text('500.0 KB'), findsOneWidget);

      // Tap delete
      final deleteIcon = find.byIcon(Icons.close);
      expect(deleteIcon, findsOneWidget);
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });

    testWidgets('AiAdviserHandoffCard renders human consultant CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const Scaffold(
            body: AiAdviserHandoffCard(
              reason: 'نیاز به بررسی دقیق پرونده توسط وکیل رسمی دارید؟',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مشاوره تخصصی با کارشناسان و وکلای مهاجرتی راد'), findsOneWidget);
      expect(find.text('نیاز به بررسی دقیق پرونده توسط وکیل رسمی دارید؟'), findsOneWidget);
      expect(find.text('درخواست وقت مشاوره'), findsOneWidget);
    });
  });

  group('RAD User AI Assistant — Responsive Layout', () {
    testWidgets('renders drawer on mobile screen (390px)', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          surfaceSize: const Size(390, 844),
          child: const AiAssistantPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Mobile: History icon opens drawer
      final historyBtn = find.byTooltip('تاریخچه گفتگوها');
      expect(historyBtn, findsOneWidget);

      await tester.tap(historyBtn);
      await tester.pumpAndSettle();

      // Drawer is opened
      expect(find.text('گفتگوی جدید'), findsOneWidget);
    });

    testWidgets('renders persistent sidebar on desktop screen (1200px)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          surfaceSize: const Size(1200, 800),
          child: const AiAssistantPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Desktop: persistent sidebar with new chat button is directly visible
      expect(find.text('گفتگوی جدید'), findsOneWidget);
    });
  });
}
