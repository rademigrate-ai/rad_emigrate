import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/admin_operations_repository.dart';

/// UI access follows the server-owned profile role. RPCs and RLS independently
/// enforce authorization; no role is inferred from editable user metadata.
class AdminRouteGate extends ConsumerWidget {
  const AdminRouteGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    Widget restricted(Widget body) => Scaffold(
      appBar: AppBar(leading: const AppBackButton(fallback: '/profile')),
      body: body,
    );
    return ref
        .watch(adminSnapshotProvider)
        .when(
          loading: () =>
              restricted(LoadingState.section(message: l10n.loading)),
          error: (_, _) => restricted(
            ErrorState(
              message: l10n.errorGeneric,
              onRetry: () => ref.invalidate(adminSnapshotProvider),
            ),
          ),
          data: (snapshot) => snapshot.canAccess
              ? child
              : restricted(ErrorState(message: l10n.adminAccessRequired)),
        );
  }
}
