import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/premium_visuals.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/notification_reader.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(authenticatedUserIdProvider);
    return _NotificationsPageForIdentity(
      key: ValueKey(identity),
      identity: identity,
    );
  }
}

class _NotificationsPageForIdentity extends ConsumerStatefulWidget {
  const _NotificationsPageForIdentity({super.key, required this.identity});
  final String? identity;

  @override
  ConsumerState<_NotificationsPageForIdentity> createState() =>
      _NotificationsPageState();
}

class _NotificationsPageState
    extends ConsumerState<_NotificationsPageForIdentity> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted || widget.identity == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = widget.identity;
      if (uid == null) return;
      final rows = await ref.read(notificationReaderProvider)(uid);
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(rows);
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

  Future<bool> _markRead(String id) async {
    try {
      final client = ref.read(supabaseClientServiceProvider).client;
      final uid = widget.identity;
      if (uid == null) return false;
      await client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', uid)
          .eq('id', id);
      if (!mounted || ref.read(authenticatedUserIdProvider) != uid) {
        return false;
      }
      await _load();
      return _error == null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markAllRead() async {
    try {
      final client = ref.read(supabaseClientServiceProvider).client;
      final uid = widget.identity;
      if (uid == null) return;
      await client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', uid)
          .filter('read_at', 'is', null);
      if (!mounted || ref.read(authenticatedUserIdProvider) != uid) return;
      await _load();
      if (_error != null && mounted) _showUpdateError();
    } catch (_) {
      if (mounted) _showUpdateError();
    }
  }

  void _showUpdateError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).notificationLoadFailed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (widget.identity == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallback: '/profile'),
          title: Text(l10n.notificationsTitle),
        ),
        body: PremiumCanvas(
          child: Center(
            child: TextButton(
              onPressed: () => context.go('/login?from=%2Fnotifications'),
              child: Text(l10n.signIn),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/profile'),
        title: Text(l10n.notificationsTitle),
        actions: [
          IconButton(
            tooltip: l10n.markAllRead,
            onPressed: _markAllRead,
            icon: const Icon(Icons.done_all),
          ),
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: PremiumCanvas(
        child: _loading
            ? LoadingState.section(message: l10n.loading)
            : _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : _items.isEmpty
            ? EmptyState(
                title: l10n.noNotifications,
                icon: Icons.notifications_none,
              )
            : ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final n = _items[i];
                  final unread = n['read_at'] == null;
                  return MotionStagger(
                    index: i,
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      onTap: () async {
                        final id = n['id'] as String?;
                        if (id != null && unread && !await _markRead(id)) {
                          if (context.mounted) _showUpdateError();
                          return;
                        }
                        final path = n['action_path'] as String?;
                        if (path != null && path.startsWith('/')) {
                          if (context.mounted) context.go(path);
                        }
                      },
                      child: ListTile(
                        leading: Icon(
                          unread
                              ? Icons.notifications_active
                              : Icons.notifications_none,
                        ),
                        title: Text('${n['title'] ?? ''}'),
                        subtitle: Text('${n['body'] ?? ''}'),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
