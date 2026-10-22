import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/search_entities.dart';

/// Safely renders text with highlighted substrings based on character ranges.
/// Prevents raw HTML injection while supporting exact snippet highlighting.
class SafeHighlightedText extends StatelessWidget {
  final String text;
  final List<MatchRange> matchRanges;
  final TextStyle? defaultStyle;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  const SafeHighlightedText({
    super.key,
    required this.text,
    required this.matchRanges,
    this.defaultStyle,
    this.highlightStyle,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final baseStyle =
        defaultStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          height: 1.5,
        ) ??
        const TextStyle(color: AppColors.textPrimary, height: 1.5);

    final markStyle =
        highlightStyle ??
        baseStyle.copyWith(
          backgroundColor: AppColors.primaryRed.withValues(alpha: 0.15),
          fontWeight: FontWeight.w700,
          color: AppColors.darkRed,
        );

    if (matchRanges.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: overflow ?? TextOverflow.ellipsis,
      );
    }

    // Sort and sanitize ranges within bounds
    final sortedRanges = List<MatchRange>.from(matchRanges)
      ..sort((a, b) => a.start.compareTo(b.start));

    final spans = <TextSpan>[];
    var currentPos = 0;

    for (final range in sortedRanges) {
      final start = range.start.clamp(0, text.length);
      final end = range.end.clamp(0, text.length);

      if (start > currentPos) {
        spans.add(
          TextSpan(text: text.substring(currentPos, start), style: baseStyle),
        );
      }

      if (end > start && start >= currentPos) {
        spans.add(TextSpan(text: text.substring(start, end), style: markStyle));
        currentPos = end;
      }
    }

    if (currentPos < text.length) {
      spans.add(TextSpan(text: text.substring(currentPos), style: baseStyle));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.ellipsis,
    );
  }
}
