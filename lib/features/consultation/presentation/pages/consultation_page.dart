import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/supabase/supabase_providers.dart';
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
  late final TextEditingController _topic;
  late final TextEditingController _message;
  bool _submitting = false;
  String? _error;
  String? _success;
  List<Map<String, dynamic>> _mine = const [];

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
    final client = ref.read(supabaseClientServiceProvider).client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final rows = await client
          .from('consultation_requests')
          .select('id, topic, status, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(20);
      if (mounted) {
        setState(() => _mine = List<Map<String, dynamic>>.from(rows as List));
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final topic = _topic.text.trim();
    final message = _message.text.trim();
    if (topic.isEmpty || message.isEmpty) {
      setState(() => _error = l10n.consultationFieldsRequired);
      return;
    }
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });
    try {
      final client = ref.read(supabaseClientServiceProvider).client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw Exception('auth');
      await client.from('consultation_requests').insert({
        'user_id': uid,
        'topic': topic,
        'message': message,
        'status': 'submitted',
      });
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
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/login'),
            child: Text(l10n.signIn),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.consultationTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.consultationIntro,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _topic,
            decoration: InputDecoration(labelText: l10n.consultationTopic),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            decoration: InputDecoration(labelText: l10n.consultationMessage),
            minLines: 4,
            maxLines: 8,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_success != null) ...[
            const SizedBox(height: 8),
            Text(
              _success!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? l10n.loading : l10n.submitConsultation),
          ),
          const SizedBox(height: 28),
          Text(
            l10n.myConsultations,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_mine.isEmpty)
            Text(l10n.noConsultations)
          else
            ..._mine.map(
              (r) => ListTile(
                title: Text('${r['topic'] ?? ''}'),
                subtitle: Text(
                  '${r['status'] ?? ''} · ${r['created_at'] ?? ''}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
