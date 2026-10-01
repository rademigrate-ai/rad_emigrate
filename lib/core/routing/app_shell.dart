import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const items = [
    ('Home', '/dashboard', Icons.home_outlined),
    ('Visa', '/visa', Icons.public),
    ('Applications', '/applications', Icons.assignment_outlined),
    ('Documents', '/documents', Icons.folder_outlined),
    ('Profile', '/profile', Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          if (MediaQuery.sizeOf(context).width >= 800)
            NavigationRail(
              destinations: [for (final item in items) NavigationRailDestination(icon: Icon(item.$3), label: Text(item.$1))],
              selectedIndex: 0,
              onDestinationSelected: (i) => context.go(items[i].$2),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 800
          ? NavigationBar(
              destinations: [for (final item in items) NavigationDestination(icon: Icon(item.$3), label: item.$1)],
              onDestinationSelected: (i) => context.go(items[i].$2),
            )
          : null,
    );
  }
}
