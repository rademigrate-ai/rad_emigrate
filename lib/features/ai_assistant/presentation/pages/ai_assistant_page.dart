import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependencies.dart';
import '../../../../core/services/ai/ai_request.dart';
import '../../../../core/services/ai/ai_response.dart';
import '../../../../core/supabase/rad_contract.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/rad_ai_bird.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../providers/ai_assistant_activity_provider.dart';
import '../providers/ai_prompt_draft_provider.dart';
import '../widgets/ai_citation_card.dart';

class _ChatMessage {
  _ChatMessage({
    required this.isUser,
    required this.text,
    this.sources,
    this.retryPrompt,
    this.retryRequest,
  });

  final bool isUser;
  final String text;
  final List<AiSource>? sources;
  final String? retryPrompt;
  final AiRequest? retryRequest;
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
  var _loading = false;
  var _birdState = RadAiBirdState.idle;
  Timer? _birdTimer;

  String? _sessionId;
  late Future<void> _historyRestore;
  int _identityEpoch = 0;
  ProviderSubscription<String?>? _identitySubscription;

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
          text: 'What documents should I prepare for my visa pathway?',
        ),
        _ChatMessage(
          isUser: false,
          text: 'I can help you organize the published requirements. I will keep uncertain information clearly marked and point you to official sources when available.',
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
      if (sessions.isEmpty ||
          !mounted ||
          ref.read(authenticatedUserIdProvider) != userId) {
        return;
      }
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
    if (text.isEmpty || _loading) return;

    final userId = ref.read(authenticatedUserIdProvider);
    final epoch = _identityEpoch;
    if (userId == null || userId.isEmpty) {
      await ref
          .read(aiPromptDraftProvider.notifier)
          .savePrompt(text, widget.contextLabel);
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
      sessionId ??= (await repository.createSession(
        userId,
        scope: widget.adminMode ? 'admin' : 'user',
      )).id;
      if (!_sameIdentity(userId, epoch)) return;
      _sessionId = sessionId;
      await repository.saveMessage(
        sessionId: _sessionId!,
        userId: userId,
        role: 'user',
        content: text,
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
      _messages.add(_ChatMessage(isUser: true, text: text));
      _loading = true;
      _controller.clear();
    });
    await ref.read(aiPromptDraftProvider.notifier).clearDraft();
    _scrollToEnd();

    await _complete(text, userId);
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
    // The v1 terminal errors below are cached by backend settlement; the
    // legacy provider rejection is also a definitive failure. Recovery is a
    // user-requested new attempt. Ambiguous transport and
    // settlement failures retain the old key to recover the existing result.
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
      metadata: {...request.metadata, 'request_key': newRadRequestKey()},
    );
  }

  Future<void> _complete(
    String text,
    String? userId, {
    _ChatMessage? replacing,
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

    // Preserve the original retry input, including locale/history. Keeping
    // the complete input avoids both duplicate quota charges and changed-body
    // conflicts when the UI locale changes after an ambiguous transport error.
    final request =
        replacing?.retryRequest ??
        AiRequest(
          prompt: text,
          kind: AiRequestKind.immigrationQuestion,
          conversationId: _sessionId,
          locale: locale,
          history: history,
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
      setState(() {
        if (replacing != null) _messages.remove(replacing);
        _messages.add(
          _ChatMessage(
            isUser: false,
            text: response.text,
            sources: response.sources,
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
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: AppMotion.duration(context, AppMotion.standard),
          curve: AppMotion.curve(context),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final suggestions = [
      l10n.suggestionStudyPermitDocuments,
      l10n.suggestionVisaProcessingTime,
      l10n.suggestionGteStatement,
      l10n.suggestionComparePathways,
    ];
    const suggestionColors = [
      Color(0xFFD91F2B),
      Color(0xFF345CFF),
      Color(0xFF00A986),
      Color(0xFF3186DA),
    ];
    const suggestionIcons = [
      Icons.school_outlined,
      Icons.work_outline,
      Icons.trending_up,
      Icons.public_outlined,
    ];
    final draftContext = ref.watch(aiPromptDraftProvider).contextLabel;
    final effectiveContext =
        (widget.contextLabel != null && widget.contextLabel!.trim().isNotEmpty)
        ? widget.contextLabel
        : draftContext;

    final body = PremiumCanvas(
      accent: context.premium.accent,
      child: AmbientBackdrop(
        active: _loading,
        child: Column(
          children: [
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
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  RadAiBird(
                                    state: _birdState,
                                    semanticLabel: _birdSemanticLabel(context),
                                    size: 140,
                                    showBackgroundOrb: false,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.howCanWeHelp,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 12),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 380,
                                    ),
                                    child: Text(
                                      l10n.askAboutVisas,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            ...suggestions.asMap().entries.map(
                              (entry) => MotionStagger(
                                index: entry.key,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: AppCard(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    onTap: () => _send(entry.value),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: suggestionColors[entry.key]
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              AppRadii.sm,
                                            ),
                                          ),
                                          child: Icon(
                                            suggestionIcons[entry.key],
                                            size: 17,
                                            color: suggestionColors[entry.key],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text(entry.value)),
                                        Icon(
                                          directionalChevron(context),
                                          size: 18,
                                          color: context.premium.mutedText,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_loading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_loading && index == _messages.length) {
                          return Padding(
                            padding: const EdgeInsets.all(8),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Semantics(
                                liveRegion: true,
                                label: _birdSemanticLabel(context),
                                child: ExcludeSemantics(
                                  child: AppCard(
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                          8,
                                          6,
                                          18,
                                          6,
                                        ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        RadAiBird(
                                          state: RadAiBirdState.thinking,
                                          semanticLabel: l10n.loading,
                                          size: 64,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          l10n.loading,
                                          style: TextStyle(
                                            color: context.premium.text,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              constraints: BoxConstraints(
                                maxWidth: math.min(
                                  680,
                                  MediaQuery.sizeOf(context).width * 0.85,
                                ),
                              ),
                              decoration: BoxDecoration(
                                color: m.isUser
                                    ? context.premium.accent
                                    : context.premium.surface,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.md,
                                ),
                                border: Border.all(
                                  color: m.isUser
                                      ? context.premium.accent
                                      : context.premium.border,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.text,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: m.isUser
                                              ? context.premium.onAccent
                                              : context.premium.text,
                                        ),
                                  ),
                                  if (m.retryPrompt != null &&
                                      index == _messages.length - 1)
                                    TextButton.icon(
                                      onPressed: _loading
                                          ? null
                                          : () => _retry(m),
                                      icon: const Icon(Icons.refresh),
                                      label: Text(l10n.retry),
                                    ),
                                  if (m.sources != null &&
                                      m.sources!.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    for (var i = 0; i < m.sources!.length; i++)
                                      AiCitationCard(
                                        index: i + 1,
                                        source: m.sources![i],
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (!widget.embedded)
              Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Text(
                    widget.adminMode
                        ? l10n.untrustedResearchDisclaimer
                        : l10n.aiDisclaimer,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.premium.mutedText),
                  ),
                ),
              ),
            SafeArea(
              child: Container(
                color: context.premium.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _composerFocus,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: l10n.askQuestionHint,
                            fillColor: context.premium.surfaceElevated,
                            hintStyle: TextStyle(
                              color: context.premium.mutedText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: l10n.sendMessage,
                        style: IconButton.styleFrom(
                          backgroundColor: context.premium.accent,
                          foregroundColor: context.premium.onAccent,
                          disabledBackgroundColor:
                              context.premium.disabledSurface,
                          disabledForegroundColor: context.premium.disabledText,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _loading ? null : () => _send(),
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.adminMode ? l10n.adminResearchAssistant : l10n.aiAssistant,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: body,
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
