import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/dependencies.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/ai/ai_request.dart';
import '../../../../core/services/ai/ai_response.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

class _ChatMessage {
  _ChatMessage({required this.isUser, required this.text, this.sources});

  final bool isUser;
  final String text;
  final List<AiSource>? sources;
}

class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({super.key, this.adminMode = false});

  final bool adminMode;

  @override
  ConsumerState<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends ConsumerState<AiAssistantPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMessage>[];
  var _loading = false;
  static const _freeLimit = 5;
  var _used = 0;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _restoreHistory();
  }

  Future<void> _restoreHistory() async {
    final userId = ref.read(authControllerProvider).valueOrNull?.userId;
    if (userId == null || userId.isEmpty) return;
    try {
      final repository = ref.read(aiSessionRepositoryProvider);
      final sessions = await repository.listSessions(userId);
      if (sessions.isEmpty || !mounted) return;
      final session = sessions.first;
      final history = await repository.history(session.id);
      if (!mounted) return;
      setState(() {
        _sessionId = session.id;
        _used = session.questionCount;
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
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final l10n = AppLocalizations.of(context);
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _loading) return;
    if (_used >= _freeLimit) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.aiQuotaExhausted)));
      return;
    }

    final userId = ref.read(authControllerProvider).valueOrNull?.userId;
    try {
      if (userId != null && userId.isNotEmpty) {
        final repository = ref.read(aiSessionRepositoryProvider);
        _sessionId ??= (await repository.createSession(userId)).id;
        await repository.saveMessage(
          sessionId: _sessionId!,
          userId: userId,
          role: 'user',
          content: text,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.couldNotSaveQuestion)));
      }
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text));
      _loading = true;
      _controller.clear();
      _used++;
    });
    _scrollToEnd();

    try {
      final ai = ref.read(aiServiceProvider);
      final locale = Localizations.localeOf(context).languageCode;
      final response = ai.isAvailable
          ? await ai.complete(
              AiRequest(
                prompt: text,
                kind: AiRequestKind.immigrationQuestion,
                conversationId: _sessionId,
                locale: locale,
                metadata: {if (widget.adminMode) 'scope': 'admin'},
              ),
            )
          : AiResponse(text: l10n.aiUnavailableResponse(text), uncertain: true);
      if (userId != null && userId.isNotEmpty && _sessionId != null) {
        await ref
            .read(aiSessionRepositoryProvider)
            .saveMessage(
              sessionId: _sessionId!,
              userId: userId,
              role: 'assistant',
              content: response.text,
            );
      }
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            isUser: false,
            text: response.text,
            sources: response.sources,
          ),
        );
        _loading = false;
      });
      _scrollToEnd();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(isUser: false, text: l10n.errorGeneric));
        _loading = false;
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final suggestions = [
      l10n.suggestionStudyPermitDocuments,
      l10n.suggestionVisaProcessingTime,
      l10n.suggestionGteStatement,
    ];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.adminMode ? l10n.adminResearchAssistant : l10n.aiAssistant,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                l10n.freeQuota(_used, _freeLimit),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                widget.adminMode
                    ? l10n.untrustedResearchDisclaimer
                    : l10n.aiDisclaimer,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        l10n.howCanWeHelp,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.askAboutVisas,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ...suggestions.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(onTap: () => _send(s), child: Text(s)),
                        ),
                      ),
                    ],
