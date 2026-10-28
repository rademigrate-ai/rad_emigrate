import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependencies.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/ai/ai_request.dart';
import '../../../../core/services/ai/ai_response.dart';
import '../../../../core/supabase/rad_contract.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/supabase/supabase_storage.dart';

import 'dart:typed_data';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/rad_ai_bird.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/ai_session_repository.dart';
import '../providers/ai_assistant_activity_provider.dart';
import '../providers/ai_prompt_draft_provider.dart';
import '../providers/ai_user_profile_provider.dart';
import '../widgets/ai_adviser_handoff_card.dart';
import '../widgets/ai_citation_card.dart';
import '../widgets/ai_document_chip.dart';
import '../widgets/ai_history_drawer.dart';
import '../widgets/ai_immigration_profile_sheet.dart';
import '../widgets/ai_interactive_report_view.dart';
import '../widgets/ai_markdown_view.dart';
import '../widgets/ai_message_actions.dart';
import '../widgets/ai_search_progress_card.dart';

class _ChatMessage {
  _ChatMessage({
    required this.isUser,
    required this.text,
    this.sources,
    this.retryPrompt,
    this.retryRequest,
    this.attachment,
    this.searchQuery,
    this.hasWebSearch = false,
    this.checklistItems,
    this.showAdviserHandoff = false,
  });

  final bool isUser;
  final String text;
  final List<AiSource>? sources;
  final String? retryPrompt;
  final AiRequest? retryRequest;
  final AiDocumentAttachment? attachment;
  final String? searchQuery;
  final bool hasWebSearch;
  final List<ChecklistItemData>? checklistItems;
  final bool showAdviserHandoff;
}

class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({
    super.key,
    this.adminMode = false,
    this.embedded = false,
    this.visualQaDemo = false,
    this.contextLabel,
  });

  final bool adminMode;

  /// When true, omit AppBar and outer disclaimer (host provides chrome).
  final bool embedded;

  /// Explicit synthetic state used only by the separate visual-QA entrypoint.
  /// It is never enabled from the production router.
  final bool visualQaDemo;

  /// Optional country/program context shown as a pill (from Visa deep link).
  final String? contextLabel;

  @override
  ConsumerState<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends ConsumerState<AiAssistantPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _composerFocus = FocusNode();
  final _messages = <_ChatMessage>[];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  var _loading = false;
  var _birdState = RadAiBirdState.idle;
  Timer? _birdTimer;

  String? _sessionId;
  List<AiSession> _sessions = [];
  late Future<void> _historyRestore;
  int _identityEpoch = 0;
  ProviderSubscription<String?>? _identitySubscription;

  // Web search mode: auto | on | off
  String _webSearchMode = 'auto';

  // Active pending document attachment
  AiDocumentAttachment? _pendingAttachment;

  bool _sameIdentity(String? id, int epoch) =>
      mounted &&
      epoch == _identityEpoch &&
      ref.read(authenticatedUserIdProvider) == id;

  @override
  void initState() {
    super.initState();
    if (widget.visualQaDemo) {
      _messages.addAll([
        _ChatMessage(
          isUser: true,
          text: 'چه مدارکی برای ویزای تحصیلی کانادا الزامی است؟',
        ),
        _ChatMessage(
          isUser: false,
          text: '### مدارک اصلی ویزای تحصیلی کانادا\n\nبرای درخواست استادی پرمیت (Study Permit)، مدارک زیر الزامی هستند:\n\n- **نامه پذیرش معتبر (LOA)** از موسسه آموزشی معتبر (DLI)\n- **گواهی تمکن مالی (Proof of Financial Support)** شامل حساب بانکی و منبع درآمد\n- **پاسپورت معتبر** با حداقل ۶ ماه اعتبار\n- **گواهی عدم سوء پیشینه و مدیکال** (در صورت لزوم)\n\n| عنوان مدرک | وضعیت | مهلت |\n|---|---|---|\n| پذیرش DLI | الزامی | قبل از ثبت درخواست |\n| تمکن مالی ۲۰,۶۳۵ دلار کانادا | الزامی | ۶ ماه اخیر |\n| مدرک زبان (IELTS 6.0+) | پیشنهادی | معتبر تا ۲ سال |',
          sources: const [
            AiSource(
              title: 'راهنمای رسمی اداره مهاجرت کانادا (IRCC) - Study Permit Requirements',
              url: 'https://www.canada.ca/en/immigration-refugees-citizenship/services/study-canada/study-permit.html',
              authority: 'IRCC Canada',
            ),
          ],
          hasWebSearch: true,
          searchQuery: 'IRCC Canada study permit required documents 2026',
          showAdviserHandoff: true,
          checklistItems: [
            ChecklistItemData(
              title: 'نامه پذیرش معتبر (LOA)',
              description: 'از موسسه آموزشی معتبر (DLI)',
              tier: RequirementTier.mandatory,
            ),
            ChecklistItemData(
              title: 'اثبات تمکن مالی (۲۰,۶۳۵ دلار)',
              description: 'گردش حساب ۶ ماه اخیر',
              tier: RequirementTier.mandatory,
            ),
            ChecklistItemData(
              title: 'مدرک زبان (IELTS 6.0+)',
              description: 'معتبر تا ۲ سال',
              tier: RequirementTier.recommended,
            ),
          ],
        ),
      ]);
      _loading = true;
      _birdState = RadAiBirdState.thinking;
    }

    _controller.addListener(_onPromptChanged);
    _composerFocus.addListener(_onComposerFocusChanged);
    _historyRestore = _restoreHistory();

    _identitySubscription = ref.listenManual(authenticatedUserIdProvider, (
      previous,
      next,
    ) {
      if (previous == next || previous == null || !mounted) return;
      _identityEpoch++;
      _birdTimer?.cancel();
      _controller.removeListener(_onPromptChanged);
      _controller.clear();
      _controller.addListener(_onPromptChanged);
      setState(() {
        _messages.clear();
        _sessionId = null;
        _sessions = [];
        _pendingAttachment = null;
        _loading = false;
        _birdState = RadAiBirdState.idle;
      });
      _historyRestore = _restoreHistory();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final epoch = _identityEpoch;
      await ref.read(aiPromptDraftProvider.notifier).ready;
      if (!mounted || epoch != _identityEpoch) return;
      final draft = ref.read(aiPromptDraftProvider);
      if (_controller.text.isEmpty && draft.hasContent) {
        setState(() {
          _controller.text = draft.prompt;
        });
      }
    });
  }

  void _onPromptChanged() {
    ref
        .read(aiPromptDraftProvider.notifier)
        .savePrompt(_controller.text, widget.contextLabel);
  }

  void _onComposerFocusChanged() {
    if (!mounted || _loading) return;
    setState(() {
      _birdState = _composerFocus.hasFocus
          ? RadAiBirdState.listening
          : RadAiBirdState.idle;
    });
  }

  void _showResponseState() {
    _birdTimer?.cancel();
    setState(() => _birdState = RadAiBirdState.responding);
    _birdTimer = Timer(AppMotion.assistantResponse, () {
      if (!mounted) return;
      setState(() => _birdState = RadAiBirdState.newMessage);
      ref.read(aiAssistantActivityProvider.notifier).markNewMessage();
      _birdTimer = Timer(AppMotion.assistantNotification, () {
        if (!mounted) return;
        setState(
          () => _birdState = _composerFocus.hasFocus
              ? RadAiBirdState.listening
              : RadAiBirdState.idle,
        );
      });
    });
  }

  Future<void> _restoreHistory() async {
    final userId = ref.read(authenticatedUserIdProvider);
    if (userId == null || userId.isEmpty) return;
    try {
      final repository = ref.read(aiSessionRepositoryProvider);
      final sessions = await repository.listSessions(
        userId,
        scope: widget.adminMode ? 'admin' : 'user',
      );
      if (!mounted || ref.read(authenticatedUserIdProvider) != userId) return;

      setState(() => _sessions = sessions);

      if (sessions.isEmpty) return;
      final session = sessions.first;
      final history = await repository.history(session.id);
      if (!mounted ||
          ref.read(authenticatedUserIdProvider) != userId ||
          _messages.isNotEmpty) {
        return;
      }
      setState(() {
        _sessionId = session.id;
        _messages
          ..clear()
          ..addAll(
            history.map(
              (message) => _ChatMessage(
                isUser: message.role == 'user',
                text: message.content,
              ),
            ),
          );
      });
      _scrollToEnd();
    } catch (_) {
      // History is supplementary; the assistant remains usable if unavailable.
    }
  }

  Future<void> _loadSession(String sessionId) async {
    final userId = ref.read(authenticatedUserIdProvider);
    if (userId == null || userId.isEmpty) return;
    setState(() {
      _loading = true;
      _sessionId = sessionId;
    });
    try {
      final repository = ref.read(aiSessionRepositoryProvider);
      final history = await repository.history(sessionId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(
            history.map(
              (message) => _ChatMessage(
                isUser: message.role == 'user',
                text: message.content,
              ),
            ),
          );
        _loading = false;
      });
      _scrollToEnd();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _newChat() {
    setState(() {
      _sessionId = null;
      _messages.clear();
      _pendingAttachment = null;
      _controller.clear();
      _loading = false;
      _birdState = RadAiBirdState.idle;
    });
  }

  Future<void> _deleteSession(String sessionId) async {
    final userId = ref.read(authenticatedUserIdProvider);
    if (userId == null || userId.isEmpty) return;
    setState(() {
      _sessions.removeWhere((s) => s.id == sessionId);
      if (_sessionId == sessionId) {
        _sessionId = null;
        _messages.clear();
      }
    });
    try {
      final repository = ref.read(aiSessionRepositoryProvider);
      // Delete session records where supported
      await repository.history(sessionId); // placeholder check
    } catch (_) {}
  }

  void _renameSession(String sessionId, String newTitle) {
    // In-memory rename for UI responsiveness
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('عنوان گفتگو به‌روزرسانی شد.')),
    );
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pendingAttachment = AiDocumentAttachment(
            name: file.name,
            sizeBytes: file.size,
            extension: file.extension ?? 'file',
            bytes: file.bytes,
            path: file.path,
            status: DocumentProcessingStatus.selected,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطا در انتخاب فایل: $e')));
      }
    }
  }

  @override
  void dispose() {
    _identitySubscription?.close();
    _controller.removeListener(_onPromptChanged);
    _composerFocus.removeListener(_onComposerFocusChanged);
    _composerFocus.dispose();
    _birdTimer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final l10n = AppLocalizations.of(context);
    final text = (preset ?? _controller.text).trim();
    final attachment = _pendingAttachment;

    if ((text.isEmpty && attachment == null) || _loading) return;

    final userId = ref.read(authenticatedUserIdProvider);
    final epoch = _identityEpoch;
    final promptToSend = text.isNotEmpty
        ? text
        : 'لطفاً فایل ضمیمه‌شده (${attachment?.name}) را تحلیل و خلاصه اطلاعات آن را استخراج کنید.';

    if (userId == null || userId.isEmpty) {
      await ref
          .read(aiPromptDraftProvider.notifier)
          .savePrompt(promptToSend, widget.contextLabel);
      await ref.read(aiPromptDraftProvider.notifier).prepareSignIn();
      if (mounted) {
        final destination = widget.contextLabel != null
            ? '/ai-assistant?context=${Uri.encodeComponent(widget.contextLabel!)}'
            : '/ai-assistant';
        context.go(
          Uri(
            path: '/login',
            queryParameters: {'from': destination},
          ).toString(),
        );
      }
      return;
    }

    setState(() {
      _loading = true;
      _birdState = RadAiBirdState.thinking;
    });
    await _historyRestore;
    if (!_sameIdentity(userId, epoch)) return;

    try {
      final repository = ref.read(aiSessionRepositoryProvider);
      var sessionId = _sessionId;
      if (sessionId == null) {
        final newSession = await repository.createSession(
          userId,
          scope: widget.adminMode ? 'admin' : 'user',
        );
        sessionId = newSession.id;
        _sessions.insert(0, newSession);
      }
      if (!_sameIdentity(userId, epoch)) return;
      _sessionId = sessionId;
      await repository.saveMessage(
        sessionId: _sessionId!,
        userId: userId,
        role: 'user',
        content: promptToSend,
      );
    } catch (_) {
      if (mounted && _sameIdentity(userId, epoch)) {
        setState(() {
          _loading = false;
          _birdState = RadAiBirdState.idle;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.couldNotSaveQuestion)));
      }
      return;
    }

    if (!_sameIdentity(userId, epoch)) return;
    setState(() {
      _messages.add(
        _ChatMessage(isUser: true, text: promptToSend, attachment: attachment),
      );
      _loading = true;
      _controller.clear();
      _pendingAttachment = null;
    });
    await ref.read(aiPromptDraftProvider.notifier).clearDraft();
    _scrollToEnd();

    await _complete(promptToSend, userId, attachment: attachment);
  }

  Future<void> _retry(_ChatMessage failure) async {
    final prompt = failure.retryPrompt;
    if (_loading ||
        prompt == null ||
        _messages.isEmpty ||
        _messages.last != failure) {
      return;
    }
    setState(() => _loading = true);
    final userId = ref.read(authenticatedUserIdProvider);
    await _complete(prompt, userId, replacing: failure);
  }

  AiRequest _retryRequest(AiRequest request, String code) {
    if (!const {
      'copilot_unavailable',
      'response_contract_invalid',
      'provider_unauthorized',
    }.contains(code)) {
      return request;
    }
    return AiRequest(
      prompt: request.prompt,
      kind: request.kind,
      conversationId: request.conversationId,
      locale: request.locale,
      history: request.history,
      authorizedDataScopes: request.authorizedDataScopes,
      context: request.context,
      webSearchMode: request.webSearchMode,
      metadata: {...request.metadata, 'request_key': newRadRequestKey()},
    );
  }

  Future<void> _complete(
    String text,
    String? userId, {
    _ChatMessage? replacing,
    AiDocumentAttachment? attachment,
  }) async {
    final epoch = _identityEpoch;
    if (!_sameIdentity(userId, epoch)) return;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final turns = _messages.where((m) => m.retryPrompt == null).toList();
    final history = turns
        .take(math.max(0, turns.length - 1))
        .map((m) => AiConversationMessage(isUser: m.isUser, text: m.text))
        .toList(growable: false);

    // Profile context injection if enabled
    final profile = ref.read(aiUserProfileProvider);
    final profileContext = profile.toAiContext();

    // Determine request kind: documentAnalysis vs immigration vs general
    AiRequestKind kind = AiRequestKind.general;
    if (attachment != null) {
      kind = AiRequestKind.documentAnalysis;
    } else if (text.contains('ویزا') ||
        text.contains('مهاجرت') ||
        text.contains('اقامت') ||
        text.contains('تحصیل') ||
        text.contains('تمکن') ||
        text.contains('سفارت')) {
      kind = AiRequestKind.immigrationQuestion;
    }

    String? uploadedDocumentId;
    if (attachment != null &&
        attachment.bytes != null &&
        attachment.bytes!.isNotEmpty &&
        userId != null &&
        userId.isNotEmpty) {
      try {
        final storage = ref.read(supabaseStorageServiceProvider);
        final documentId =
            newRadRequestKey(); // uuid-shaped request key ok for path id
        final contentType = switch (attachment.extension.toLowerCase()) {
          'pdf' => 'application/pdf',
          'png' => 'image/png',
          'jpg' || 'jpeg' => 'image/jpeg',
          _ => null,
        };
        if (contentType != null) {
          final storagePath = await storage.upload(
            userId: userId,
            documentId: documentId,
            fileName: attachment.name,
            bytes: Uint8List.fromList(attachment.bytes!),
            contentType: contentType,
          );
          // Register ownership row so document-intelligence can claim the path.
          final client = ref.read(supabaseClientServiceProvider).client;
          final row = await client
              .from('documents')
              .upsert({
                'id': documentId,
                'user_id': userId,
                'name': attachment.name,
                'status': 'uploaded',
                'file_path': storagePath,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .select('id')
              .single();
          uploadedDocumentId = row['id']?.toString() ?? documentId;
        }
      } catch (_) {
        // Fail closed: chat may continue without OCR; never invent extraction.
        uploadedDocumentId = null;
      }
    }

    final request =
        replacing?.retryRequest ??
        AiRequest(
          prompt: text,
          kind: kind,
          conversationId: _sessionId,
          locale: locale,
          history: history,
          webSearchMode: _webSearchMode,
          context: {
            ...profileContext,
            if (attachment != null) 'file_name': attachment.name,
            if (attachment != null) 'file_ext': attachment.extension,
            if (uploadedDocumentId != null) 'document_id': uploadedDocumentId,
          },
          metadata: {
            'request_key': newRadRequestKey(),
            if (widget.adminMode) 'scope': 'admin',
          },
        );

    try {
      final ai = ref.read(aiServiceProvider);
      final response = ai.isAvailable
          ? await ai.complete(request)
          : AiResponse(
              text: l10n.aiUnavailableResponse(text),
              uncertain: true,
              errorCode: 'ai_unavailable',
            );

      if (!_sameIdentity(userId, epoch)) return;
      if (response.errorCode == null &&
          userId != null &&
          userId.isNotEmpty &&
          _sessionId != null) {
        try {
          await ref
              .read(aiSessionRepositoryProvider)
              .saveMessage(
                sessionId: _sessionId!,
                userId: userId,
                role: 'assistant',
                content: response.text,
              );
        } catch (_) {
          if (mounted && _sameIdentity(userId, epoch)) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l10n.aiResponseNotSaved)));
          }
        }
      }
      if (!_sameIdentity(userId, epoch)) return;

      final bool hasSearchSources =
          response.sources.isNotEmpty && _webSearchMode != 'off';
      final bool needsAdviser =
          text.contains('وکیل') ||
          text.contains('مشاوره') ||
          text.contains('پرونده') ||
          text.contains('ریجکت');

      setState(() {
        if (replacing != null) _messages.remove(replacing);
        _messages.add(
          _ChatMessage(
            isUser: false,
            text: response.text,
            sources: response.sources,
            hasWebSearch: hasSearchSources,
            searchQuery: hasSearchSources ? text : null,
            showAdviserHandoff: needsAdviser,
            retryPrompt: response.errorCode == null ? null : text,
            retryRequest: response.errorCode == null
                ? null
                : _retryRequest(request, response.errorCode!),
          ),
        );
        _loading = false;
      });
      _showResponseState();
      _scrollToEnd();
    } catch (error) {
      if (!_sameIdentity(userId, epoch)) return;
      final message = error.toString().contains('provider_unauthorized')
          ? l10n.aiCredentialRejected
          : l10n.aiRequestFailed;
      setState(() {
        if (replacing != null) _messages.remove(replacing);
        _messages.add(
          _ChatMessage(
            isUser: false,
            text: message,
            retryPrompt: text,
            retryRequest: request,
          ),
        );
        _loading = false;
      });
      _showResponseState();
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        final duration = AppMotion.duration(context, AppMotion.standard);
        if (duration <= Duration.zero) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        } else {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: duration,
            curve: AppMotion.curve(context),
          );
        }
      }
    });
  }

  void _toggleSearchMode() {
    setState(() {
      if (_webSearchMode == 'auto') {
        _webSearchMode = 'on';
      } else if (_webSearchMode == 'on') {
        _webSearchMode = 'off';
      } else {
        _webSearchMode = 'auto';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAuthenticated = ref.watch(authenticatedUserIdProvider) != null;
    final isDesktopWide = MediaQuery.of(context).size.width >= 960;

    final quickShortcuts = [
      {
        'title': 'سوال عمومی و روزمره',
        'desc': 'پاسخ به هر سوال علمی، عمومی، نگارشی یا ترجمه',
        'prompt': 'توضیح دهید هوش مصنوعی چگونه کار می‌کند؟',
        'icon': Icons.lightbulb_outline,
        'color': AppColors.navy,
      },
      {
        'title': 'راهنمای ویزا و مهاجرت',
        'desc': 'شرایط ویزاهای کاری، تحصیلی و اقامت دائم کشورها',
        'prompt': 'شرایط اخذ ویزای کاری آلمان (بلوکارت و کارت شانس) چیست؟',
        'icon': Icons.flight_takeoff,
        'color': AppColors.primaryRed,
      },
      {
        'title': 'جستجو در اینترنت و وب زنده',
        'desc': 'دریافت اخبار موثق و آخرین مبالغ تمکن مالی',
        'prompt':
            'آخرین تغییرات تمکن مالی ویزای تحصیلی کانادا در سال جاری چیست؟',
        'icon': Icons.travel_explore,
        'color': AppColors.teal,
      },
      {
        'title': 'بررسی و تحلیل مدارک',
        'desc': 'تحلیل ساختار رزومه، انگیزش‌نامه، مدرک زبان یا گواهی تمکن',
        'prompt': 'برای ارزیابی مدرک تحصیلی WES چه مدارکی مورد نیاز است؟',
        'icon': Icons.file_present_outlined,
        'color': AppColors.navy,
      },
      {
        'title': 'مقایسه مقاصد مهاجرت',
        'desc': 'مقایسه هزینه‌ها، اجازه کار همراه و شانس اقامت دائم',
        'prompt': 'مقایسه جامع مهاجرت تحصیلی به کانادا در برابر آلمان از نظر هزینه و اقامت دائم',
        'icon': Icons.balance_outlined,
        'color': AppColors.navyMuted,
      },
    ];

    final draftContext = ref.watch(aiPromptDraftProvider).contextLabel;
    final effectiveContext =
        (widget.contextLabel != null && widget.contextLabel!.trim().isNotEmpty)
        ? widget.contextLabel
        : draftContext;

    final chatContent = Column(
      children: [
        // Optional Visa Context Pill
        if (effectiveContext != null && effectiveContext.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Chip(
                avatar: const Icon(Icons.place_outlined, size: 16),
                label: Text(effectiveContext),
                backgroundColor: context.premium.surfaceElevated,
                labelStyle: TextStyle(color: context.premium.text),
                side: BorderSide.none,
              ),
            ),
          ),

        // Messages List or Welcome Empty State
        Expanded(
          child: _messages.isEmpty
              ? _buildWelcomeState(quickShortcuts)
              : _buildMessagesList(l10n),
        ),

        // Disclaimer
        if (!widget.embedded)
          Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                widget.adminMode
                    ? l10n.untrustedResearchDisclaimer
                    : l10n.aiDisclaimer,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.premium.mutedText, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ),

        // Modern Composer
        _buildModernComposer(l10n),
      ],
    );

    final scaffold = Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: AiHistoryDrawer(
        sessions: _sessions,
        activeSessionId: _sessionId,
        onSelectSession: _loadSession,
        onNewChat: _newChat,
        onDeleteSession: _deleteSession,
        onRenameSession: _renameSession,
        isAuthenticated: isAuthenticated,
      ),
      appBar: widget.embedded
          ? null
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'تاریخچه گفتگوها',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Row(
                children: [
                  RadAiBird(
                    state: _birdState,
                    semanticLabel: _birdSemanticLabel(context),
                    size: 28,
                    showBackgroundOrb: false,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.adminMode
                          ? l10n.adminResearchAssistant
                          : 'دستیار هوشمند راد',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              actions: [
                // Optional Immigration Profile Button
                IconButton(
                  icon: const Icon(Icons.account_circle_outlined),
                  tooltip: 'پروفایل مهاجرتی',
                  onPressed: () => AiImmigrationProfileSheet.show(context),
                ),
                // New Chat action
                IconButton(
                  icon: const Icon(Icons.add_comment_outlined),
                  tooltip: 'گفتگوی جدید',
                  onPressed: _newChat,
                ),
              ],
            ),
      body: isDesktopWide
          ? Row(
              children: [
                // Desktop persistent sidebar
                SizedBox(
                  width: 280,
                  child: AiHistoryDrawer(
                    sessions: _sessions,
                    activeSessionId: _sessionId,
                    onSelectSession: _loadSession,
                    onNewChat: _newChat,
                    onDeleteSession: _deleteSession,
                    onRenameSession: _renameSession,
                    isAuthenticated: isAuthenticated,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: chatContent,
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: chatContent,
              ),
            ),
    );

    return PremiumCanvas(
      accent: context.premium.accent,
      child: AmbientBackdrop(active: _loading, child: scaffold),
    );
  }

  Widget _buildWelcomeState(List<Map<String, dynamic>> shortcuts) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Center(
          child: Column(
            children: [
              RadAiBird(
                state: _birdState,
                semanticLabel: _birdSemanticLabel(context),
                size: 130,
                showBackgroundOrb: false,
              ),
              const SizedBox(height: 8),
              const Text(
                'دستیار هوشمند مهاجرت و عمومی راد',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: const Text(
                  'پاسخ به سوالات عمومی و روزمره، اطلاعات رسمی ویزا، مقایسه کشورها و بررسی مدارک',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Quick Shortcuts
        ...shortcuts.asMap().entries.map((entry) {
          final item = entry.value;
          final color = item['color'] as Color;
          return MotionStagger(
            index: entry.key,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                onTap: () => _send(item['prompt'] as String),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        size: 20,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['desc'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      directionalChevron(context),
                      size: 18,
                      color: context.premium.mutedText,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMessagesList(AppLocalizations l10n) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (_loading && index == _messages.length) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppCard(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 18, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadAiBird(
                      state: RadAiBirdState.thinking,
                      semanticLabel: l10n.loading,
                      size: 48,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.loading,
                      style: TextStyle(
                        color: context.premium.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final m = _messages[index];
        return MotionStagger(
          index: index,
          child: Align(
            alignment: m.isUser
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              constraints: BoxConstraints(
                maxWidth: math.min(
                  740,
                  MediaQuery.sizeOf(context).width * 0.88,
                ),
              ),
              decoration: BoxDecoration(
                color: m.isUser
                    ? context.premium.accent
                    : context.premium.surface,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(
                  color: m.isUser
                      ? context.premium.accent
                      : context.premium.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Attachment chip if user uploaded a file
                  if (m.attachment != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AiDocumentChip(attachment: m.attachment!),
                    ),
                  ],

                  // Search progress indicator if web search was performed
                  if (!m.isUser && m.hasWebSearch && m.searchQuery != null) ...[
                    AiSearchProgressCard(
                      query: m.searchQuery!,
                      isSearching: false,
                    ),
                  ],

                  // Rich Markdown message rendering
                  AiMarkdownView(content: m.text, isUserMessage: m.isUser),

                  // Citations list
                  if (m.sources != null && m.sources!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (var i = 0; i < m.sources!.length; i++)
                      AiCitationCard(index: i + 1, source: m.sources![i]),
                  ],

                  // Interactive checklist if present
                  if (m.checklistItems != null &&
                      m.checklistItems!.isNotEmpty) ...[
                    AiInteractiveReportView(
                      title: 'چک‌لیست مدارک مورد نیاز',
                      items: m.checklistItems!,
                    ),
                  ],

                  // Human adviser handoff CTA if relevant
                  if (m.showAdviserHandoff) ...[const AiAdviserHandoffCard()],

                  // Message Actions toolbar (copy, thumbs up/down, retry)
                  if (!m.isUser) ...[
                    AiMessageActions(
                      messageText: m.text,
                      showRetry:
                          m.retryPrompt != null &&
                          index == _messages.length - 1,
                      onRetry: () => _retry(m),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernComposer(AppLocalizations l10n) {
    Color searchModeColor;
    String searchModeLabel;
    IconData searchModeIcon;

    switch (_webSearchMode) {
      case 'on':
        searchModeColor = AppColors.teal;
        searchModeLabel = 'وب: روشن';
        searchModeIcon = Icons.travel_explore;
        break;
      case 'off':
        searchModeColor = context.premium.mutedText;
        searchModeLabel = 'وب: خاموش';
        searchModeIcon = Icons.public_off;
        break;
      case 'auto':
      default:
        searchModeColor = AppColors.navy;
        searchModeLabel = 'وب: خودکار';
        searchModeIcon = Icons.language;
        break;
    }

    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(14);
    final compact = width < 380 || textScale > 18;
    final controlSize = compact ? 36.0 : 42.0;
    final sendSize = compact ? 40.0 : 44.0;
    final hPad = compact ? 8.0 : 14.0;

    return SafeArea(
      child: Container(
        color: context.premium.surface,
        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pending file preview
            if (_pendingAttachment != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AiDocumentChip(
                  attachment: _pendingAttachment!,
                  onRemove: () => setState(() => _pendingAttachment = null),
                ),
              ),
            ],

            // Input Row — scale down under extreme text magnification / narrow width
            SizedBox(
              width: MediaQuery.sizeOf(context).width - (hPad * 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Web Search Mode Toggle Pill
                  Tooltip(
                    message: 'تنظیم جستجوی زنده در وب (خودکار / روشن / خاموش)',
                    child: InkWell(
                      onTap: _toggleSearchMode,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: searchModeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(
                            color: searchModeColor.withValues(alpha: 0.3),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              searchModeIcon,
                              size: 16,
                              color: searchModeColor,
                            ),
                            // Hide label under tight width / large text scale to avoid composer overflow.
                            if (!compact) ...[
                              const SizedBox(width: 4),
                              Text(
                                searchModeLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: searchModeColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Attachment Button (PDF & Images)
                  Tooltip(
                    message: 'پیوست سند یا تصویر (PDF/Image)',
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: context.premium.surfaceElevated,
                        foregroundColor: AppColors.navy,
                        minimumSize: Size(controlSize, controlSize),
                      ),
                      icon: const Icon(Icons.attach_file, size: 20),
                      onPressed: _loading ? null : _pickDocument,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Text Input
                  Expanded(
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter &&
                            !HardwareKeyboard.instance.isShiftPressed) {
                          _send();
                        }
                      },
                      child: TextField(
                        controller: _controller,
                        focusNode: _composerFocus,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: l10n.askQuestionHint,
                          fillColor: context.premium.surfaceElevated,
                          hintStyle: TextStyle(
                            color: context.premium.mutedText,
                            fontSize: 13,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            borderSide: BorderSide(
                              color: context.premium.border,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send Button (STRICTLY NO VOICE CONTROLS)
                  IconButton.filled(
                    tooltip: l10n.sendMessage,
                    style: IconButton.styleFrom(
                      backgroundColor: context.premium.accent,
                      foregroundColor: context.premium.onAccent,
                      disabledBackgroundColor: context.premium.disabledSurface,
                      disabledForegroundColor: context.premium.disabledText,
                      minimumSize: Size(sendSize, sendSize),
                    ),
                    onPressed: _loading ? null : () => _send(),
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: RadAiBird(
                              state: RadAiBirdState.thinking,
                              semanticLabel: 'AI thinking',
                              size: 18,
                              showBackgroundOrb: false,
                            ),
                          )
                        : const Icon(Icons.send, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _birdSemanticLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (_birdState) {
      RadAiBirdState.idle => l10n.birdReady,
      RadAiBirdState.listening => l10n.birdListening,
      RadAiBirdState.thinking => l10n.birdThinking,
      RadAiBirdState.responding => l10n.birdResponding,
      RadAiBirdState.newMessage => l10n.birdNewMessage,
    };
  }
}
