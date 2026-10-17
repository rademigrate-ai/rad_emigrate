import 'package:flutter/material.dart';

import '../theme/premium_tokens.dart';

/// Persistent form feedback; transient confirmations use a SnackBar.
class InlineAlert extends StatelessWidget {
  const InlineAlert({super.key, required this.message, this.error = true});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) {
    final tokens = context.premium;
    final color = error ? tokens.error : tokens.information;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          border: Border.all(color: color.withValues(alpha: .3)),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              error ? Icons.error_outline : Icons.info_outline,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
