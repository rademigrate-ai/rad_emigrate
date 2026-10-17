import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/data/admin_operations_repository.dart';
import '../../l10n/app_localizations.dart';
import 'rad_glass_surface.dart';

/// Visible discovery keeps the approved five-tab capsule intact.
class SecondaryDestinations extends ConsumerWidget {
  const SecondaryDestinations({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canAdmin =
        ref.watch(adminSnapshotProvider).valueOrNull?.canAccess == true;
    final destinations = [
      (l10n.worldTimeTitle, Icons.schedule_outlined, '/world-clock'),
      (l10n.feed, Icons.newspaper_outlined, '/feed'),
      (l10n.documents, Icons.folder_outlined, '/documents'),
      (l10n.consultationTitle, Icons.support_agent_outlined, '/consultation'),
      (l10n.notificationsTitle, Icons.notifications_outlined, '/notifications'),
      if (canAdmin) (l10n.admin, Icons.admin_panel_settings_outlined, '/admin'),
    ];
    return RadGlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.more,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final item in destinations)
            ListTile(
              leading: Icon(item.$2),
              title: Text(item.$1),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(item.$3),
            ),
        ],
      ),
    );
  }
}
