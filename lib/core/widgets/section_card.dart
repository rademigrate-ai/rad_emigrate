import 'package:flutter/material.dart';

import 'app_card.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? child;
  final VoidCallback? onTap;
  final IconData? icon;

  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.child,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: theme.colorScheme.secondary),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (subtitle case final subtitle?)
                      Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (trailing case final value?) ...[
                const SizedBox(width: 12),
                value,
              ],
            ],
          ),
          if (child case final value?) ...[const SizedBox(height: 12), value],
        ],
      ),
    );
  }
}
