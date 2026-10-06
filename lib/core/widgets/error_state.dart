import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'app_button.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Semantics(
          label: message,
          liveRegion: true,
          explicitChildNodes: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
              ExcludeSemantics(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                AppButton(
                  label: AppLocalizations.of(context).retry,
                  onPressed: onRetry,
                  expanded: false,
                  variant: AppButtonVariant.secondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
