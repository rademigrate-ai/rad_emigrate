import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/dependencies.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/ai/ai_request.dart';
import '../../../../core/services/ai/ai_response.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

class _ChatMessage {
  _ChatMessage({required this.isUser, required this.text, this.sources});

  final bool isUser;
  final String text;
  final List<AiSource>? sources;
}

class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({super.key});

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

  static const _suggestions = [
    'What documents are typically needed for a study permit?',
    'How long can a visa process take?',
    'What is a GTE statement?',
  ];

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
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _loading) return;
    if (_used >= _freeLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Free AI questions used for this session. Limits are configurable for production.',
          ),
        ),
      );
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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save this question: $error')),
        );
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
      final response = await ai.complete(
        AiRequest(prompt: text, kind: AiRequestKind.immigrationQuestion),
      );
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            isUser: false,
            text: 'Something went wrong. Please try again.',
          ),
        );
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$_used / $_freeLimit free',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: AppColors.surfaceMuted,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'Sourced answers are unavailable until the RAD Knowledge Base is configured. '
                'Nothing here is an official immigration decision.',
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
                        'How can we help?',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ask about visas, documents, or process. Try a suggestion:',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ..._suggestions.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(onTap: () => _send(s), child: Text(s)),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_loading && index == _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final m = _messages[index];
                      return Align(
                        alignment: m.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.85,
                          ),
                          decoration: BoxDecoration(
                            color: m.isUser
                                ? AppColors.primaryRed.withValues(alpha: 0.1)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: m.isUser
                                  ? AppColors.primaryRed.withValues(alpha: 0.2)
                                  : AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.text,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              if (m.sources != null &&
                                  m.sources!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ...m.sources!.map(
                                  (s) => Text(
                                    'Source: ${s.title}'
                                    '${s.authority != null ? ' (${s.authority})' : ''}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask a question…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _loading ? null : () => _send(),
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
