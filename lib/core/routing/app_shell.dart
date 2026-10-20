import '../widgets/app_back_button.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../widgets/rad_brand.dart';
import '../widgets/app_entrance.dart';
import '../widgets/rad_ai_bird_nav_icon.dart';
import '../widgets/rad_phoenix_navigation_surface.dart';
import '../theme/app_motion.dart';
import '../theme/premium_tokens.dart';
import '../widgets/rad_ai_bird.dart';
import '../../l10n/app_localizations.dart';
import '../../features/admin/data/admin_operations_repository.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  var _railExtended = true;

  int _selectedIndex(String location, List<_NavItem> items) {
    for (var i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
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
        label: l10n.explore,
        path: '/visa',
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore,
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

    // Mobile primary: Home | Visa | AI bird | Feed | Profile
    final primary = [items[0], items[1], items[4], items[7]];
    final overflow = items
        .where(
          (item) =>
              item.path != '/dashboard' &&
              item.path != '/visa' &&
              item.path != '/feed' &&
              item.path != '/profile' &&
              item.path != '/ai-assistant',
        )
        .toList();

    final railItems = [
      items[0],
      items[1],
      items[6],
      items[4],
      items[7],
      items[2],
      _NavItem(
        label: l10n.more,
        path: '/more',
        icon: Icons.more_horiz,
        selectedIcon: Icons.more_horiz,
      ),
    ];
    final secondary = [
      ...overflow,
      _NavItem(
        label: l10n.consultationTitle,
        path: '/consultation',
        icon: Icons.support_agent_outlined,
        selectedIcon: Icons.support_agent,
      ),
      _NavItem(
        label: l10n.notificationsTitle,
        path: '/notifications',
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
      ),
    ];
    final selected = railItems.any((item) => location.startsWith(item.path))
        ? _selectedIndex(location, railItems)
        : 6;
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;
    final aiSelected = location.startsWith('/ai-assistant');

    const fallbacks = {
      '/world-clock': '/dashboard',
      '/feed': '/dashboard',
      '/consultation': '/dashboard',
      '/documents': '/profile',
      '/notifications': '/profile',
      '/applications': '/profile',
      '/profile/cases': '/profile',
      '/admin': '/profile',
      '/admin/ai-config': '/admin',
      '/admin/operations': '/admin',
      '/admin/consultations': '/admin',
      '/admin/ai-research': '/admin',
      '/admin/cms': '/admin',
      '/admin/sources': '/admin',
    };
    final shell = Scaffold(
      // Keep route content above the navigation surface. Extending behind the
      // bar made the last controls unreadable and untappable on compact views.
      extendBody: false,
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
                extended: _railExtended,
                selectedIndex: selected,
                onDestinationSelected: (i) async {
                  if (railItems[i].path != '/more') {
                    context.go(railItems[i].path);
                    return;
                  }
                  final path = await _showMore(context, secondary, location);
                  if (path != null && context.mounted) context.push(path);
                },
                labelType: _railExtended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                backgroundColor: Colors.transparent,
                groupAlignment: -0.55,
                minWidth: 80,
                minExtendedWidth: 236,
                leading: Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 20),
                  child: Column(
                    children: [
                      RadBrand(
                        size: RadBrandSize.small,
                        showInstituteName: false,
                        darkSurface: context.premium.isDark,
                      ),
                      const SizedBox(height: 10),
                      IconButton(
                        tooltip: _railExtended
                            ? l10n.collapseNavigation
                            : l10n.expandNavigation,
                        onPressed: () =>
                            setState(() => _railExtended = !_railExtended),
                        icon: Icon(
                          _railExtended
                              ? (Directionality.of(context) == TextDirection.rtl
                                    ? Icons.keyboard_double_arrow_right
                                    : Icons.keyboard_double_arrow_left)
                              : (Directionality.of(context) == TextDirection.rtl
                                    ? Icons.keyboard_double_arrow_left
                                    : Icons.keyboard_double_arrow_right),
                        ),
                      ),
                    ],
                  ),
                ),
                destinations: [
                  for (final item in railItems)
                    NavigationRailDestination(
                      icon: item.path == '/ai-assistant'
                          ? RadAiBird(
                              state: RadAiBirdState.idle,
                              size: 28,
                              semanticLabel: item.label,
                            )
                          : Icon(item.icon),
                      selectedIcon: item.path == '/ai-assistant'
                          ? RadAiBird(
                              state: RadAiBirdState.idle,
                              size: 28,
                              semanticLabel: item.label,
                            )
                          : Icon(item.selectedIcon),
                      label: Text(item.label),
                    ),
                ],
              ),
            ),
          Expanded(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: AppEntrance(key: ValueKey(location), child: widget.child),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide || MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : _RadBottomBar(
              primary: primary,
              location: location,
              aiSelected: aiSelected,
              aiLabel: l10n.aiAssistant,
              moreLabel: l10n.more,
              onPrimarySelected: (path) => context.go(path),
              onAiTap: () => context.go('/ai-assistant'),
              onMore: () async {
                final path = await _showMore(context, secondary, location);
                if (path != null && context.mounted) context.push(path);
              },
            ),
    );
    final fallback = fallbacks[location];
    return fallback == null
        ? shell
        : BackFallbackScope(fallback: fallback, child: shell);
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

class _RadBottomBar extends StatelessWidget {
  const _RadBottomBar({
    required this.primary,
    required this.location,
    required this.aiSelected,
    required this.aiLabel,
    required this.moreLabel,
    required this.onPrimarySelected,
    required this.onAiTap,
    required this.onMore,
  });

  final List<_NavItem> primary;
  final String location;
  final bool aiSelected;
  final String aiLabel;
  final String moreLabel;
  final ValueChanged<String> onPrimarySelected;
  final VoidCallback onAiTap;
  final VoidCallback onMore;

  bool _isSelected(_NavItem item) => location.startsWith(item.path);

  @override
  Widget build(BuildContext context) {
    final left = primary.take(2).toList();
    final right = primary.skip(2).toList();
    return RadPhoenixNavigationSurface(
      leading: [
        for (final item in left)
          _NavSlot(
            item: item,
            selected: _isSelected(item) && !aiSelected,
            onTap: () => onPrimarySelected(item.path),
          ),
      ],
      trailing: [
        for (final item in right)
          _NavSlot(
            item: item,
            selected: _isSelected(item) && !aiSelected,
            onTap: () => onPrimarySelected(item.path),
          ),
      ],
      phoenix: RadAiBirdNavIcon(
        selected: aiSelected,
        label: aiLabel,
        moreLabel: moreLabel,
        onTap: onAiTap,
        onLongPress: onMore,
      ),
    );
  }
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelHeight = RadPhoenixNavigationSurface.labelHeight(context);
    final color = selected
        ? context.premium.accentForeground
        : context.premium.mutedText;

    return Semantics(
      identifier: 'rad-navigation-${item.path.substring(1)}',
      label: item.label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              if (selected)
                Positioned(
                  bottom: 7,
                  child: Container(
                    width: 48,
                    height: labelHeight + 38,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          context.premium.accent.withValues(alpha: .18),
                          context.premium.accent.withValues(alpha: .04),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                ),
              Positioned(
                bottom: labelHeight + 8,
                child: AnimatedScale(
                  duration: AppMotion.duration(
                    context,
                    AppMotion.buttonFeedback,
                  ),
                  scale: selected ? 1.05 : 1,
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    size: 24,
                    color: color,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 7,
                child: SizedBox(
                  height: labelHeight,
                  child: Center(
                    child: Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: RadPhoenixNavigationSurface.labelLines(context),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
