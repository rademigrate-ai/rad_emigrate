import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_motion.dart';

/// Application timeline step state (avoids clash with Material StepState).
enum ProgressStepState { done, current, upcoming }

class ProgressStep {
  const ProgressStep({required this.label, required this.state});

  final String label;
  final ProgressStepState state;
}

/// Vertical application timeline. State changes animate only when supplied by
/// actual backend data; no visual state is synthesized by this widget.
class ProgressSteps extends StatelessWidget {
  const ProgressSteps({super.key, required this.steps});

  final List<ProgressStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepRow(step: steps[i], isLast: i == steps.length - 1),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.isLast});

  final ProgressStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = step.state == ProgressStepState.done;
    final current = step.state == ProgressStepState.current;
    final color = done
        ? AppColors.success
        : current
        ? scheme.secondary
        : scheme.onSurfaceVariant;
    final duration = AppMotion.duration(context, AppMotion.progress);

    return Semantics(
      label: step.label,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                AnimatedScale(
                  duration: duration,
                  curve: AppMotion.curve(
                    context,
                    preferred: AppMotion.emphasizedCurve,
                  ),
                  scale: current ? 1.1 : 1,
                  child: AnimatedContainer(
                    duration: duration,
                    curve: AppMotion.curve(context),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: done || current ? color : scheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                      boxShadow: current
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.2),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : const [],
                    ),
                    child: done
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : current
                        ? const Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox(width: 8, height: 8),
                            ),
                          )
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: AnimatedContainer(
                      duration: duration,
                      curve: AppMotion.curve(context),
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: done
                          ? AppColors.success.withValues(alpha: 0.55)
                          : theme.dividerColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                child: AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: AppMotion.curve(context),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                    color: current || done
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                  child: Text(step.label),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
