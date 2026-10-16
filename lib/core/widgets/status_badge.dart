import 'package:flutter/material.dart';

import '../theme/premium_tokens.dart';
import '../../l10n/app_localizations.dart';

enum StatusTone { neutral, info, warning, success, danger }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
  });

  final String label;
  final StatusTone tone;

  Color _bg(BuildContext context) => switch (tone) {
    StatusTone.neutral => Theme.of(context).colorScheme.surfaceContainerHighest,
    StatusTone.info => context.premium.information.withValues(alpha: 0.12),
    StatusTone.warning => context.premium.warning.withValues(alpha: 0.14),
    StatusTone.success => context.premium.success.withValues(alpha: 0.12),
    StatusTone.danger => context.premium.error.withValues(alpha: 0.12),
  };

  Color _fg(BuildContext context) => switch (tone) {
    StatusTone.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
    StatusTone.info => context.premium.information,
    StatusTone.warning => context.premium.warning,
    StatusTone.success => context.premium.success,
    StatusTone.danger => context.premium.error,
  };

  IconData get _icon => switch (tone) {
    StatusTone.neutral => Icons.circle_outlined,
    StatusTone.info => Icons.info_outline,
    StatusTone.warning => Icons.schedule_outlined,
    StatusTone.success => Icons.check_circle_outline,
    StatusTone.danger => Icons.error_outline,
  };

  @override
  Widget build(BuildContext context) {
    final foreground = _fg(context);
    return Semantics(
      label: '${AppLocalizations.of(context).statusLabel}: $label',
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _bg(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 14, color: foreground),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
