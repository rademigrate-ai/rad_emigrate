import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../widgets/rad_brand.dart';
import '../widgets/app_entrance.dart';
import '../theme/app_motion.dart';
import '../../l10n/app_localizations.dart';
import '../../features/admin/data/admin_operations_repository.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _selectedIndex(String location, List<_NavItem> items) {
    for (var i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final location = GoRouterState.of(context).matchedLocation;
    final canAccessAdmin =
        ref.watch(adminSnapshotProvider).valueOrNull?.canAccess == true;
    final items = [
      _NavItem(
        label: l10n.home,
        path: '/dashboard',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      _NavItem(
        label: l10n.visa,
        path: '/visa',
        icon: Icons.public_outlined,
        selectedIcon: Icons.public,
      ),
      _NavItem(
        label: l10n.cases,
        path: '/applications',
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment,
      ),
      _NavItem(
        label: l10n.worldTimeTitle,
        path: '/world-clock',
        icon: Icons.schedule_outlined,
        selectedIcon: Icons.schedule,
      ),
      _NavItem(
        label: l10n.feed,
        path: '/feed',
        icon: Icons.newspaper_outlined,
        selectedIcon: Icons.newspaper,
      ),
      _NavItem(
        label: l10n.docs,
        path: '/documents',
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder,
      ),
      _NavItem(
        label: l10n.aiAssistant,
        path: '/ai-assistant',
        icon: Icons.smart_toy_outlined,
        selectedIcon: Icons.smart_toy,
      ),
      _NavItem(
        label: l10n.profile,
        path: '/profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
      ),
      if (canAccessAdmin)
        _NavItem(
          label: l10n.admin,
          path: '/admin',
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
        ),
    ];
    final selected = _selectedIndex(location, items);
    final compactItems = items.take(4).toList();
    final compactSelected = _selectedIndex(location, compactItems);
    final isCompactRoute = compactItems.any(
      (item) => location.startsWith(item.path),
    );
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: Row(
        children: [
          if (wide)
            Container(
              decoration: BoxDecoration(
                color:
                    Theme.of(context).navigationRailTheme.backgroundColor ??
                    AppColors.navy,
                border: BorderDirectional(
                  end: BorderSide(
                    color: Theme.of(context).dividerColor
                        .withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: NavigationRail(
                selectedIndex: selected,
                onDestinationSelected: (i) => context.go(items[i].path),
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.transparent,
                groupAlignment: -0.55,
                minWidth: 116,
                leading: const Padding(
                  padding: EdgeInsets.only(top: 18, bottom: 28),
                  child: RadBrand(
                    size: RadBrandSize.small,
                    showInstituteName: false,
                  ),
                ),
                destinations: [
                  for (final item in items)
                    NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: Text(item.label),
                    ),
                ],
              ),
            ),
          Expanded(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: AppEntrance(key: ValueKey(location), child: child),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: isCompactRoute ? compactSelected : 4,
              onDestinationSelected: (i) async {
                if (i < compactItems.length) {
                  context.go(compactItems[i].path);
                  return;
                }
                final path = await _showMore(
                  context,
                  items.skip(compactItems.length).toList(),
                  location,
                );
                if (path != null && context.mounted) context.go(path);
              },
              destinations: [
                for (final item in compactItems)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: item.label,
                  ),
                NavigationDestination(
                  icon: const Icon(Icons.more_horiz),
                  selectedIcon: const Icon(Icons.more),
                  label: l10n.more,
                ),
              ],
            ),
    );
  }

  Future<String?> _showMore(
    BuildContext context,
    List<_NavItem> items,
    String location,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      sheetAnimationStyle: AnimationStyle(
        duration: AppMotion.duration(context, AppMotion.modal),
        reverseDuration: AppMotion.duration(context, AppMotion.fast),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          children: [
            for (final item in items)
              ListTile(
                selected: location.startsWith(item.path),
                leading: Icon(
                  location.startsWith(item.path)
                      ? item.selectedIcon
                      : item.icon,
                ),
                title: Text(item.label),
                onTap: () => Navigator.pop(sheetContext, item.path),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}
