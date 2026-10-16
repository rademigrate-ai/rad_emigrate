import 'package:flutter/material.dart';

import 'rad_flapping_bird.dart';

/// The visual density appropriate for a real pending operation.
enum RadLoadingSize { fullScreen, section, compact }

/// Branded pending feedback using the existing six-stage natural wingbeat.
/// The original bird artwork, reduced motion and ticker lifecycle are owned by
/// RadFlappingBird. This adapter supplies size and one live announcement.
class RadLoadingIndicator extends StatelessWidget {
  const RadLoadingIndicator({
    super.key,
    this.size = RadLoadingSize.section,
    required this.label,
    this.message,
    this.active = true,
    this.dark = false,
  });

  /// Prominent app-bootstrap feedback using the approved Splash visual tier.
  const RadLoadingIndicator.splash({
    super.key,
    required this.label,
    this.message,
    this.active = true,
    this.dark = true,
  }) : size = RadLoadingSize.fullScreen;

  final RadLoadingSize size;
  final String label;
  final String? message;
  final bool active;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final scene = ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final preferred = switch (size) {
            RadLoadingSize.fullScreen => 280.0,
            RadLoadingSize.section => 120.0,
            RadLoadingSize.compact => 40.0,
          };
          final dimension = constraints.hasBoundedWidth
              ? preferred.clamp(0.0, constraints.maxWidth)
              : preferred;
          return RadFlappingBird(
            size: dimension,
            active: active,
            showAura: size != RadLoadingSize.compact,
          );
        },
      ),
    );

    return Semantics(
      label: label,
      liveRegion: true,
      container: true,
      child: ExcludeSemantics(
        child: switch (size) {
          RadLoadingSize.compact => LayoutBuilder(
            builder: (context, constraints) {
              if (!constraints.hasBoundedWidth || constraints.maxWidth < 160) {
                return SizedBox(width: 40, child: scene);
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 40, child: scene),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message ?? label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              );
            },
          ),
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
