import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../widgets/rad_brand.dart';
import '../../l10n/app_localizations.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _selectedIndex(String location, List<_NavItem> items) {
    if (location.startsWith('/ai-assistant')) {
      final aiIdx = items.indexWhere((e) => e.path == '/ai-assistant');
      return aiIdx >= 0 ? aiIdx : 0;
    }
    for (var i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final location = GoRouterState.of(context).matchedLocation;
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
        label: l10n.docs,
        path: '/documents',
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder,
      ),
      _NavItem(
        label: l10n.feed,
        path: '/feed',
        icon: Icons.newspaper_outlined,
        selectedIcon: Icons.newspaper,
      ),
      _NavItem(
        label: l10n.profile,
        path: '/profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
      ),
    ];
    final selected = _selectedIndex(location, items);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: Row(
        children: [
          if (wide)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).navigationRailTheme.backgroundColor ??
                    AppColors.navy,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: NavigationRail(
                selectedIndex: selected,
                onDestinationSelected: (i) => context.go(items[i].path),
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.transparent,
                groupAlignment: -0.55,
                minWidth: 104,
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
              child: child,
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selected.clamp(0, items.length - 1),
              onDestinationSelected: (i) => context.go(items[i].path),
              destinations: [
                for (final item in items)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: item.label,
                  ),
              ],
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
