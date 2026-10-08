import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'motion_primitives.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final label = message ?? AppLocalizations.of(context).loading;
    return Center(
      child: Semantics(
        label: label,
        liveRegion: true,
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSkeleton(height: 16, width: 148),
              const SizedBox(height: 12),
              const AppSkeleton(height: 12),
              const SizedBox(height: 8),
              const AppSkeleton(height: 12, width: 236),
              const SizedBox(height: 20),
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.25,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
