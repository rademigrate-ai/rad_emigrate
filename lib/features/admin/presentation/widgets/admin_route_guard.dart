import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../l10n/app_localizations.dart';

final _verifiedAdminRoleProvider = FutureProvider.autoDispose<String>((
  ref,
) async {
  final client = ref.watch(supabaseClientServiceProvider).client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return 'user';
  final row = await client
      .from('profiles')
      .select('role')
      .eq('id', userId)
      .maybeSingle();
  return row?['role'] as String? ?? 'user';
});

/// Defense-in-depth route gate. The role is loaded from the owner-scoped
/// server profile; every sensitive query/RPC remains independently protected
/// by RLS and database authorization.
class AdminRouteGuard extends ConsumerWidget {
  const AdminRouteGuard({
    required this.child,
    this.superAdminOnly = false,
    super.key,
  });

  final Widget child;
  final bool superAdminOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ref
        .watch(_verifiedAdminRoleProvider)
        .when(
          loading: () => Scaffold(
            body: LoadingState.section(message: l10n.loadingOperational),
          ),
          error: (_, _) => _Denied(message: l10n.adminRestricted),
          data: (role) {
            final allowed = superAdminOnly
                ? role == 'super_admin'
                : role == 'admin' || role == 'super_admin';
            return allowed ? child : _Denied(message: l10n.adminRestricted);
          },
        );
  }
}

class _Denied extends StatelessWidget {
  const _Denied({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/dashboard'),
                child: const Icon(Icons.home_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
