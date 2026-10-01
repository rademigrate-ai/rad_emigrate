import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

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
    return Card(
      color: AppColors.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: Semantics(
        button: onTap != null,
        child: InkWell(
          onTap: onTap,
          overlayColor: WidgetStatePropertyAll(
            AppColors.navy.withValues(alpha: 0.05),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 22, color: AppColors.navy),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (subtitle case final subtitle?)
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    if (trailing case final value?) ...[
                      const SizedBox(width: 12),
                      value,
                    ],
                  ],
                ),
                if (child case final child?) ...[
                  const SizedBox(height: 12),
                  child,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
