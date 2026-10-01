import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Application timeline step state (avoids clash with Material StepState).
enum ProgressStepState { done, current, upcoming }

class ProgressStep {
  const ProgressStep({required this.label, required this.state});

  final String label;
  final ProgressStepState state;
}

/// Vertical application timeline (clear hierarchy).
class ProgressSteps extends StatelessWidget {
  const ProgressSteps({super.key, required this.steps});

  final List<ProgressStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _StepRow(step: steps[i], isLast: i == steps.length - 1),
        ],
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
    final done = step.state == ProgressStepState.done;
    final current = step.state == ProgressStepState.current;
    final color = done
        ? AppColors.success
        : current
            ? AppColors.primaryRed
            : AppColors.textTertiary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: done || current ? color : AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : current
                        ? Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: done
                        ? AppColors.success.withValues(alpha: 0.4)
                        : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Text(
                step.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                  color: current || done
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
