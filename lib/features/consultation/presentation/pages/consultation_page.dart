import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/record_labels.dart';
import '../../../../core/widgets/inline_alert.dart';
import '../../../../core/theme/premium_tokens.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/supabase/rpc_compat.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../providers/consultation_draft_provider.dart';

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
    final draft = ref.read(consultationDraftProvider);
    final initialTopic = widget.initialTopic?.trim();
    final effectiveTopic = (initialTopic != null && initialTopic.isNotEmpty)
        ? initialTopic
        : draft.topic;
    _topic = TextEditingController(text: effectiveTopic);
    _message = TextEditingController(text: draft.message);

    _topic.addListener(_onFieldChanged);
    _message.addListener(_onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(consultationDraftProvider.notifier).ready;
      if (!mounted) return;
      final restored = ref.read(consultationDraftProvider);
      if (_topic.text.isEmpty && restored.topic.isNotEmpty) {
        _topic.text = restored.topic;
      }
      if (_message.text.isEmpty && restored.message.isNotEmpty) {
        _message.text = restored.message;
      }
      await _loadMine();
    });
  }

  void _onFieldChanged() {
    ref
        .read(consultationDraftProvider.notifier)
        .updateDraft(topic: _topic.text, message: _message.text);
  }

  @override
  void dispose() {
    _topic.removeListener(_onFieldChanged);
    _message.removeListener(_onFieldChanged);
    _topic.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session?.authenticated != true || session?.userId == null) {
      if (mounted) setState(() => _historyLoading = false);
      return;
    }
    final supabase = ref.read(supabaseClientServiceProvider);
    if (!supabase.isInitialized) {
      if (mounted) setState(() => _historyLoading = false);
      return;
    }
    final client = supabase.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _historyLoading = false);
      return;
    }
    if (mounted) {
      setState(() {
        _historyLoading = true;
        _historyFailed = false;
      });
    }
    try {
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
    final l10n = AppLocalizations.of(context);
    final topic = _topic.text.trim();
    final message = _message.text.trim();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _error = l10n.consultationFieldsRequired);
      return;
    }

    final session = ref.read(authControllerProvider).valueOrNull;
    if (session?.authenticated != true) {
      if (mounted) {
        context.go('/login?from=%2Fconsultation');
      }
      return;
    }

    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });

    try {
      final supabase = ref.read(supabaseClientServiceProvider);
      if (!supabase.isInitialized) throw Exception('supabase_not_initialized');
      final client = supabase.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw Exception('auth');

      // Stage 1 Security Hardening: Use submit_consultation_request RPC
      // with narrow fallback to direct insert ONLY when RPC is positively not installed.
      try {
        await client.rpc(
          'submit_consultation_request',
          params: {'p_topic': topic, 'p_message': message},
        );
      } catch (e) {
        if (isRpcMissingException(e)) {
          await client.from('consultation_requests').insert({
            'user_id': uid,
            'topic': topic,
            'message': message,
            'status': 'submitted',
          });
        } else {
          // Fail closed: never fall back on permission errors, rate limits, validation, or network drops
          rethrow;
        }
      }

      await ref.read(consultationDraftProvider.notifier).clearDraft();
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
    final isAuthed = session?.authenticated == true;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/dashboard'),
        title: Text(l10n.consultationTitle),
      ),
      body: PremiumCanvas(
        accent: AppColors.primaryRed,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: MotionReveal(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  _ConsultationHeader(
                    title: l10n.consultationTitle,
                    body: l10n.consultationIntro,
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    padding: const EdgeInsets.all(22),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            AppLocalizations.of(context).requestDetailsHeading,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 18),
                          AppTextField(
                            controller: _topic,
                            label: l10n.consultationTopic,
                            prefixIcon: Icons.topic_outlined,
                            textInputAction: TextInputAction.next,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? l10n.consultationFieldsRequired
                                : null,
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: _message,
                            label: l10n.consultationMessage,
                            prefixIcon: Icons.message_outlined,
                            minLines: 5,
                            maxLines: 8,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? l10n.consultationFieldsRequired
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    InlineAlert(message: _error!),
                  ],
                  if (_success != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _success!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
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
                  if (!isAuthed)
                    AppCard(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: const Icon(Icons.lock_outline),
                        title: Text(l10n.signInToViewConsultations),
                        trailing: TextButton(
                          onPressed: () =>
                              context.go('/login?from=%2Fconsultation'),
                          child: Text(l10n.signIn),
                        ),
                      ),
                    )
                  else if (_historyLoading)
                    RadInlineLoading(label: l10n.loading)
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
                              '${consultationStatusLabel(r['status'], l10n)} · ${recordDateLabel(r['created_at'], context)}',
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsultationHeader extends StatelessWidget {
  const _ConsultationHeader({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      header: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: context.premium.heroGradient.colors,
          ),
          borderRadius: BorderRadius.circular(AppRadii.hero),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryRed.withValues(alpha: dark ? .14 : .08),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
