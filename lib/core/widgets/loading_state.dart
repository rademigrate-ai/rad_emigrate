import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'motion_primitives.dart';
import 'rad_loading.dart';

/// Branded loading feedback for page, section, and inline pending states.
///
/// Existing data providers own whether this widget exists. The constructors
/// only select visual density, so pending/error control flow remains unchanged.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message, this.dark = false})
    : size = RadLoadingSize.section;

  const LoadingState.fullScreen({super.key, this.message, this.dark = false})
    : size = RadLoadingSize.fullScreen;

  const LoadingState.section({super.key, this.message, this.dark = false})
    : size = RadLoadingSize.section;

  const LoadingState.compact({super.key, this.message, this.dark = false})
    : size = RadLoadingSize.compact;

  final String? message;
  final bool dark;
  final RadLoadingSize size;

  @override
  Widget build(BuildContext context) {
    final label = message ?? AppLocalizations.of(context).loading;
    final child = _buildVisual(context, label);
    return Semantics(
      label: label,
      liveRegion: true,
      container: true,
      excludeSemantics: true,
      child: child,
    );
  }

  Widget _buildVisual(BuildContext context, String label) {
    if (size == RadLoadingSize.compact) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: RadInlineLoading(label: label, dark: dark),
      );
    }

    final isFullScreen = size == RadLoadingSize.fullScreen;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isFullScreen ? 360 : 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadLoadingIndicator(
                size: size,
                label: label,
                message: message,
                dark: dark,
              ),
              SizedBox(height: isFullScreen ? 30 : 22),
              const _LoadingSkeletonPreview(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingSkeletonPreview extends StatelessWidget {
  const _LoadingSkeletonPreview();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(height: 14, width: 136),
          SizedBox(height: 12),
          AppSkeleton(height: 11),
          SizedBox(height: 8),
          AppSkeleton(height: 11, width: 224),
        ],
      ),
    );
  }
}
