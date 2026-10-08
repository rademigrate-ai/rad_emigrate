import 'package:flutter/material.dart';

import 'rad_earth_bird_scene.dart';

/// The visual density appropriate for a real pending operation.
enum RadLoadingSize { fullScreen, section, compact }

/// A lifecycle-safe, branded pending-operation adapter for RAD.
///
/// The visual renderer is intentionally shared with the approved Login Hero:
/// [RadEarthBirdScene] owns painting, the official bird asset, orbit geometry,
/// Reduced Motion, ticker state, repaint isolation, and controller disposal.
/// This adapter owns the density selection, contextual message, and one live
/// loading announcement for existing pending-state call sites.
class RadLoadingIndicator extends StatelessWidget {
  const RadLoadingIndicator({
    super.key,
    this.size = RadLoadingSize.section,
    required this.label,
    this.message,
    this.active = true,
    this.dark = false,
  });

  final RadLoadingSize size;
  final String label;
  final String? message;
  final bool active;
  final bool dark;

  RadEarthBirdVariant get _sceneVariant => switch (size) {
    RadLoadingSize.fullScreen => RadEarthBirdVariant.fullScreenLoading,
    RadLoadingSize.section => RadEarthBirdVariant.sectionLoading,
    RadLoadingSize.compact => RadEarthBirdVariant.compactLoading,
  };

  @override
  Widget build(BuildContext context) {
    final scene = ExcludeSemantics(
      child: RadEarthBirdScene(
        variant: _sceneVariant,
        semanticLabel: label,
        active: active,
        dark: dark,
      ),
    );

    return Semantics(
      label: label,
      liveRegion: true,
      container: true,
      child: ExcludeSemantics(
        child: switch (size) {
          RadLoadingSize.compact => scene,
          _ => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              scene,
              if (message != null) ...[
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: dark
                          ? const Color(0xFFD2E4E8)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        },
      ),
    );
  }
}

/// Compact RAD feedback for a local, non-button pending operation.
class RadInlineLoading extends StatelessWidget {
  const RadInlineLoading({
    super.key,
    required this.label,
    this.active = true,
    this.dark = false,
  });

  final String label;
  final bool active;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return RadLoadingIndicator(
      size: RadLoadingSize.compact,
      label: label,
      active: active,
      dark: dark,
    );
  }
}
