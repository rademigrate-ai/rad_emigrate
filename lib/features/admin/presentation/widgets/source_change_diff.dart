import 'package:flutter/material.dart';

import '../../domain/source_text_change.dart';

/// Selectable original text with visual and spoken change indicators. It never
/// interprets HTML or translates evidence, and reconstructs each side exactly.
class SourceChangeText extends StatelessWidget {
  const SourceChangeText({
    super.key,
    required this.before,
    required this.after,
    required this.showBefore,
    required this.isPersian,
    this.textDirection,
  });
  final String before;
  final String after;
  final bool showBefore;
  final bool isPersian;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final changed = showBefore
        ? TextChangeKind.removed
        : TextChangeKind.inserted;
    final label = showBefore
        ? (isPersian ? 'متن حذف‌شده' : 'Removed text')
        : (isPersian ? 'متن افزوده‌شده' : 'Added text');
    return SelectableText.rich(
      TextSpan(
        children: [
          for (final run in sourceTextChanges(before, after))
            if (run.kind !=
                (showBefore ? TextChangeKind.inserted : TextChangeKind.removed))
              TextSpan(
                text: run.text,
                semanticsLabel: run.kind == changed
                    ? '$label: ${run.text}'
                    : null,
                style: run.kind != changed
                    ? null
                    : TextStyle(
                        color: showBefore
                            ? colors.onErrorContainer
                            : colors.onPrimaryContainer,
                        backgroundColor: showBefore
                            ? colors.errorContainer
                            : colors.primaryContainer,
                        decoration: showBefore
                            ? TextDecoration.lineThrough
                            : TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
              ),
        ],
      ),
      textDirection: textDirection,
    );
  }
}
