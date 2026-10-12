import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

/// Explicit user-initiated consultation / human-handoff request.
class ConsultationPage extends ConsumerStatefulWidget {
  const ConsultationPage({super.key, this.initialTopic});

  final String? initialTopic;

  @override
  ConsumerState<ConsultationPage> createState() => _ConsultationPageState();
}

class _ConsultationPageState extends ConsumerState<ConsultationPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _topic;
  late final TextEditingController _message;
  bool _submitting = false;
  String? _error;
  String? _success;
  List<Map<String, dynamic>> _mine = const [];
  bool _historyLoading = true;
  bool _historyFailed = false;

  @override
  void initState() {
    super.initState();
    _topic = TextEditingController(text: widget.initialTopic ?? '');
    _message = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMine());
  }

  @override
  void dispose() {
    _topic.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    try {
      final session = ref.read(authControllerProvider).valueOrNull;
      if (session?.authenticated != true) {
        if (mounted) setState(() => _historyLoading = false);
        return;
      }
      final client = ref.read(supabaseClientServiceProvider).client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw StateError('Missing consultation session');
      if (mounted) {
        setState(() {
          _historyLoading = true;
          _historyFailed = false;
        });
      }
      final rows = await client
          .from('consultation_requests')
          .select('id, topic, status, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(20);
      if (mounted) {
        setState(() {
          _mine = List<Map<String, dynamic>>.from(rows as List);
          _historyLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _historyLoading = false;
          _historyFailed = true;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) {
      setState(() => _error = l10n.consultationFieldsRequired);
      return;
    }
    final topic = _topic.text.trim();
    final message = _message.text.trim();
    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });
    try {
      final client = ref.read(supabaseClientServiceProvider).client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw Exception('auth');
      await client.rpc(
        'submit_consultation_request',
        params: {'p_topic': topic, 'p_message': message},
      );
      if (mounted) {
        setState(() {
          _success = l10n.consultationSubmitted;
          _message.clear();
        });
        await _loadMine();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = l10n.consultationSubmitFailed);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authControllerProvider).valueOrNull;
    if (session?.authenticated != true) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.consultationTitle)),
        body: EmptyState(
          title: l10n.consultationTitle,
          subtitle: l10n.signInSubtitle,
          icon: Icons.support_agent_outlined,
          actionLabel: l10n.signIn,
          onAction: () => context.go('/login?from=%2Fconsultation'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.consultationTitle),
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
      ),
      body: MotionReveal(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              l10n.consultationIntro,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: _topic,
                      label: l10n.consultationTopic,
                      prefixIcon: Icons.topic_outlined,
                      textInputAction: TextInputAction.next,
                      enabled: !_submitting,
                      validator: (value) {
                        final length = value?.trim().length ?? 0;
                        if (length == 0) return l10n.consultationFieldsRequired;
                        return length >= 3 && length <= 200
                            ? null
                            : l10n.consultationTopicLength;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _message,
                      label: l10n.consultationMessage,
                      prefixIcon: Icons.message_outlined,
                      minLines: 4,
                      maxLines: 8,
                      enabled: !_submitting,
                      validator: (value) {
                        final length = value?.trim().length ?? 0;
                        if (length == 0) return l10n.consultationFieldsRequired;
                        return length >= 10 && length <= 5000
                            ? null
                            : l10n.consultationMessageLength;
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            if (_success != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  _success!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            AppButton(
              label: l10n.submitConsultation,
              icon: Icons.send_outlined,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: 28),
            Text(
              l10n.myConsultations,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_historyLoading)
              const Center(child: CircularProgressIndicator())
            else if (_historyFailed)
              TextButton.icon(
                onPressed: _loadMine,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.refresh),
              )
            else if (_mine.isEmpty)
              Text(l10n.noConsultations)
            else
              ..._mine.asMap().entries.map((entry) {
                final r = entry.value;
                return MotionStagger(
                  index: entry.key,
                  child: AppCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${r['topic'] ?? ''}'),
                      subtitle: Text(
                        '${r['status'] ?? ''} · ${r['created_at'] ?? ''}',
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
