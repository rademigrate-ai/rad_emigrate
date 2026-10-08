import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ref.read(supabaseClientServiceProvider).client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw Exception('auth');
      final rows = await client
          .from('notifications')
          .select('id, type, title, body, action_path, read_at, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(rows as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).notificationLoadFailed;
          _loading = false;
        });
      }
    }
  }

  Future<void> _markRead(String id) async {
    final client = ref.read(supabaseClientServiceProvider).client;
    await client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', id);
    await _load();
  }

  Future<void> _markAllRead() async {
    final client = ref.read(supabaseClientServiceProvider).client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    await client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', uid)
        .filter('read_at', 'is', null);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authControllerProvider).valueOrNull;
    if (session?.authenticated != true) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.notificationsTitle)),
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/login'),
            child: Text(l10n.signIn),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          TextButton(onPressed: _markAllRead, child: Text(l10n.markAllRead)),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _items.isEmpty
          ? Center(child: Text(l10n.noNotifications))
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = _items[i];
                final unread = n['read_at'] == null;
                return ListTile(
                  leading: Icon(
                    unread
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                  ),
                  title: Text('${n['title'] ?? ''}'),
                  subtitle: Text('${n['body'] ?? ''}'),
                  onTap: () async {
                    final id = n['id'] as String?;
                    if (id != null && unread) await _markRead(id);
                    final path = n['action_path'] as String?;
                    if (path != null && path.startsWith('/')) {
                      if (context.mounted) context.go(path);
                    }
                  },
                );
              },
            ),
    );
  }
}
