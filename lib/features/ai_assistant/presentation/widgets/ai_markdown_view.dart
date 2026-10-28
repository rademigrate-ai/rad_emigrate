import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';

/// Lightweight, crash-proof, responsive Markdown parser and renderer for RAD AI Assistant.
/// Supports headings, bold/italic, lists, native tables, and code blocks with copy action.
class AiMarkdownView extends StatelessWidget {
  const AiMarkdownView({
    super.key,
    required this.content,
    this.textStyle,
    this.isUserMessage = false,
  });

  final String content;
  final TextStyle? textStyle;
  final bool isUserMessage;

  @override
  Widget build(BuildContext context) {
    if (isUserMessage) {
      return Text(
        content,
        style: textStyle ??
            TextStyle(
              color: context.premium.onAccent,
              fontSize: 14,
              height: 1.5,
            ),
      );
    }

    final blocks = _parseMarkdownBlocks(content);
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blocks.map((b) => _renderBlock(context, b)).toList(),
      ),
    );
  }

  Widget _renderBlock(BuildContext context, _MarkdownBlock block) {
    final baseStyle = textStyle ??
        TextStyle(
          color: context.premium.text,
          fontSize: 14,
          height: 1.6,
        );

    switch (block.type) {
      case _BlockType.h1:
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Text(
            block.text,
            style: baseStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
        );
      case _BlockType.h2:
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            block.text,
            style: baseStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        );
      case _BlockType.h3:
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            block.text,
            style: baseStyle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        );
      case _BlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _renderRichInline(context, block.text, baseStyle),
        );
      case _BlockType.bulletList:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsetsDirectional.fromSTEB(0, 7, 8, 0),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: context.premium.accent,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: _renderRichInline(context, block.text, baseStyle),
              ),
            ],
          ),
        );
      case _BlockType.numberedList:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${block.number}. ',
                style: baseStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryRed,
                ),
              ),
              Expanded(
                child: _renderRichInline(context, block.text, baseStyle),
              ),
            ],
          ),
        );
      case _BlockType.quote:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: BorderDirectional(
              start: BorderSide(color: AppColors.primaryRed, width: 3),
            ),
          ),
          child: _renderRichInline(context, block.text, baseStyle),
        );
      case _BlockType.codeBlock:
        return _CodeBlockWidget(
          code: block.text,
          language: block.language ?? '',
        );
      case _BlockType.table:
        return _renderTable(context, block.rows);
      case _BlockType.divider:
        return const Divider(height: 20);
    }
  }

  Widget _renderRichInline(
    BuildContext context,
    String text,
    TextStyle baseStyle,
  ) {
    final spans = <InlineSpan>[];
    final regex = RegExp(
      r'(\*\*([^*]+)\*\*)|(\*([^*]+)\*)|(`([^`]+)`)|(\[([^\]]+)\]\(([^)]+)\))',
    );
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      if (match.group(1) != null) {
        // Bold: **text**
        spans.add(TextSpan(
          text: match.group(2),
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (match.group(3) != null) {
        // Italic: *text*
        spans.add(TextSpan(
          text: match.group(4),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (match.group(5) != null) {
        // Inline code: `code`
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: context.premium.surfaceElevated,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: context.premium.border),
            ),
            child: Text(
              match.group(6) ?? '',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.primaryRed,
              ),
            ),
          ),
        ));
      } else if (match.group(7) != null) {
        // Link: [text](url)
        final linkText = match.group(8) ?? '';
        final url = match.group(9) ?? '';
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InkWell(
            onTap: () {
              final uri = Uri.tryParse(url);
              if (uri != null) launchUrl(uri);
            },
            child: Text(
              linkText,
              style: TextStyle(
                color: AppColors.primaryRed,
                decoration: TextDecoration.underline,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return Text.rich(TextSpan(children: spans));
  }

  Widget _renderTable(BuildContext context, List<List<String>> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: context.premium.border),
          ),
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder(
              horizontalInside: BorderSide(color: context.premium.border),
              verticalInside: BorderSide(color: context.premium.border),
            ),
            children: rows.asMap().entries.map((entry) {
              final isHeader = entry.key == 0;
              final rowCells = entry.value;
              return TableRow(
                decoration: BoxDecoration(
                  color: isHeader
                      ? context.premium.surfaceElevated
                      : Colors.transparent,
                ),
                children: rowCells.map((cell) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      cell.trim(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isHeader ? FontWeight.w700 : FontWeight.normal,
                        color: isHeader ? AppColors.navy : context.premium.text,
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<_MarkdownBlock> _parseMarkdownBlocks(String raw) {
    final lines = raw.split('\n');
    final blocks = <_MarkdownBlock>[];
    List<List<String>> currentTable = [];
    bool inCodeBlock = false;
    String codeBlockLang = '';
    StringBuffer codeBlockContent = StringBuffer();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Code block start/end
      if (trimmed.startsWith('```')) {
        if (!inCodeBlock) {
          inCodeBlock = true;
          codeBlockLang = trimmed.substring(3).trim();
          codeBlockContent.clear();
        } else {
          inCodeBlock = false;
          blocks.add(_MarkdownBlock(
            type: _BlockType.codeBlock,
            text: codeBlockContent.toString().trimRight(),
            language: codeBlockLang,
          ));
        }
        continue;
      }

      if (inCodeBlock) {
        codeBlockContent.writeln(line);
        continue;
      }

      // Table line
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        // check separator line like |---|---|
        if (RegExp(r'^\|[\s-:]+\|$').hasMatch(trimmed.replaceAll('|', '||'))) {
          continue; // ignore separator
        }
        final cells = trimmed
            .substring(1, trimmed.length - 1)
            .split('|')
            .map((c) => c.trim())
            .toList();
        currentTable.add(cells);
        continue;
      } else if (currentTable.isNotEmpty) {
        blocks.add(_MarkdownBlock(
          type: _BlockType.table,
          text: '',
          rows: List.from(currentTable),
        ));
        currentTable.clear();
      }

      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('### ')) {
        blocks.add(_MarkdownBlock(
          type: _BlockType.h3,
          text: trimmed.substring(4),
        ));
      } else if (trimmed.startsWith('## ')) {
        blocks.add(_MarkdownBlock(
          type: _BlockType.h2,
          text: trimmed.substring(3),
        ));
      } else if (trimmed.startsWith('# ')) {
        blocks.add(_MarkdownBlock(
          type: _BlockType.h1,
          text: trimmed.substring(2),
        ));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        blocks.add(_MarkdownBlock(
          type: _BlockType.bulletList,
          text: trimmed.substring(2),
        ));
      } else if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        final match = RegExp(r'^(\d+)\.\s(.*)$').firstMatch(trimmed);
        blocks.add(_MarkdownBlock(
          type: _BlockType.numberedList,
          text: match?.group(2) ?? trimmed,
          number: match?.group(1),
        ));
      } else if (trimmed.startsWith('> ')) {
        blocks.add(_MarkdownBlock(
          type: _BlockType.quote,
          text: trimmed.substring(2),
        ));
      } else if (trimmed == '---' || trimmed == '***') {
        blocks.add(_MarkdownBlock(type: _BlockType.divider, text: ''));
      } else {
        blocks.add(_MarkdownBlock(
          type: _BlockType.paragraph,
          text: trimmed,
        ));
      }
    }

    if (inCodeBlock) {
      blocks.add(_MarkdownBlock(
        type: _BlockType.codeBlock,
        text: codeBlockContent.toString().trimRight(),
        language: codeBlockLang,
      ));
    }
    if (currentTable.isNotEmpty) {
      blocks.add(_MarkdownBlock(
        type: _BlockType.table,
        text: '',
        rows: currentTable,
      ));
    }

    return blocks;
  }
}

enum _BlockType {
  h1,
  h2,
  h3,
  paragraph,
  bulletList,
  numberedList,
  quote,
  codeBlock,
  table,
  divider,
}

class _MarkdownBlock {
  final _BlockType type;
  final String text;
  final String? language;
  final String? number;
  final List<List<String>> rows;

  _MarkdownBlock({
    required this.type,
    required this.text,
    this.language,
    this.number,
    this.rows = const [],
  });
}

class _CodeBlockWidget extends StatefulWidget {
  const _CodeBlockWidget({required this.code, required this.language});
  final String code;
  final String language;

  @override
  State<_CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<_CodeBlockWidget> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF181825),
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.md)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.language.isNotEmpty ? widget.language : 'code',
                  style: const TextStyle(
                    color: Color(0xFFA6ADC8),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                InkWell(
                  onTap: _copy,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check : Icons.copy,
                          size: 13,
                          color: _copied
                              ? const Color(0xFFA6E3A1)
                              : const Color(0xFFA6ADC8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copied ? 'کپی شد' : 'کپی',
                          style: TextStyle(
                            color: _copied
                                ? const Color(0xFFA6E3A1)
                                : const Color(0xFFA6ADC8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFFCDD6F4),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
