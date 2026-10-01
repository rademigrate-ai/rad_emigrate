import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../widgets/rad_brand.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _items = [
    (
      label: 'Home',
      path: '/dashboard',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    (
      label: 'Visa',
      path: '/visa',
      icon: Icons.public_outlined,
      selectedIcon: Icons.public,
    ),
    (
      label: 'Cases',
      path: '/applications',
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment,
    ),
    (
      label: 'Docs',
      path: '/documents',
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
    ),
    (
      label: 'Profile',
      path: '/profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  int _selectedIndex(String location) {
    if (location.startsWith('/ai-assistant')) return 0;
    for (var i = 0; i < _items.length; i++) {
      if (location.startsWith(_items[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selected = _selectedIndex(location);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: selected,
              onDestinationSelected: (i) => context.go(_items[i].path),
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.navy,
              minWidth: 92,
              leading: Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 20),
                child: const RadBrand(
                  size: RadBrandSize.small,
                  showInstituteName: false,
                ),
              ),
              destinations: [
                for (final item in _items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
          Expanded(
            child: ColoredBox(color: AppColors.background, child: child),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: (i) => context.go(_items[i].path),
              destinations: [
                for (final item in _items)
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
