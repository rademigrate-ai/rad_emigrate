import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/editorial_repository.dart';

class EditorialRichBlock extends StatelessWidget {
  const EditorialRichBlock({super.key, required this.block});
  final Map<String, dynamic> block;

  @override
  Widget build(BuildContext context) {
    final original = block['current_structure'] is Map
        ? Map<String, dynamic>.from(block['current_structure'] as Map)
        : block['original_structure'] is Map
        ? Map<String, dynamic>.from(block['original_structure'] as Map)
        : block;
    final type = original['type'];
    if (type == 'table') return _RichTable(table: original);
    if (type == 'bullet_list' || type == 'numbered_list') {
      final values = original['items'];
      if (values is List && values.every((v) => v is String)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < values.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SelectableText(
                  '${type == 'numbered_list' ? '${i + 1}.' : '•'} ${values[i]}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
          ],
        );
      }
      return _list(
        context,
        editorialRows(original['items']),
        type == 'numbered_list',
        0,
      );
    }
    final value = original['text'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Semantics(
        header: type == 'heading',
        child: SelectableText(
          value,
          style: type == 'heading'
              ? Theme.of(context).textTheme.titleLarge
              : Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.9),
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    List<Map<String, dynamic>> items,
    bool ordered,
    int depth,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: depth == 0 ? 0 : 18,
            top: 6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                '${ordered ? '${i + 1}.' : '•'} ${items[i]['text'] ?? ''}',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(height: 1.8),
              ),
              for (final child in editorialRows(items[i]['children']))
                _list(
                  context,
                  editorialRows(child['items']),
                  child['ordered'] == true,
                  depth + 1,
                ),
            ],
          ),
        ),
    ],
  );
}

/// A measured grid preserves colspan/rowspan without flattening cell meaning.
/// It uses Flutter text/layout on Web and Android; raw source HTML never runs.
class _RichTable extends StatelessWidget {
  const _RichTable({required this.table});
  final Map<String, dynamic> table;

  @override
  Widget build(BuildContext context) {
    final rows = table['rows'] as List? ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();
    final occupied = <(int, int)>{};
    final cells =
        <({int row, int col, int cols, int rows, Map<String, dynamic> data})>[];
    var columns = 0;
    int span(dynamic value) => (int.tryParse('$value') ?? 1).clamp(1, 100);
    for (var r = 0; r < rows.length; r++) {
      var c = 0;
      for (final cell in editorialRows(rows[r])) {
        while (occupied.contains((r, c))) {
          c++;
        }
        final cs = span(cell['colspan']);
        final rs = math.min(span(cell['rowspan']), rows.length - r);
        cells.add((row: r, col: c, cols: cs, rows: rs, data: cell));
        for (var y = r; y < r + rs; y++) {
          for (var x = c; x < c + cs; x++) {
            occupied.add((y, x));
          }
        }
        c += cs;
        columns = math.max(columns, c);
      }
    }
    if (columns == 0) return const SizedBox.shrink();
    final direction = Directionality.of(context);
    final base =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          constraints.maxWidth,
          math.min(1600.0, columns * 150.0),
        );
        final unit = width / columns;
        final heights = List<double>.filled(rows.length, 48);
        for (final cell in cells) {
          final style = cell.data['header'] == true
              ? base.copyWith(fontWeight: FontWeight.bold)
              : base;
          final painter = TextPainter(
            text: TextSpan(text: '${cell.data['text'] ?? ''}', style: style),
            textDirection: direction,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: math.max(1, unit * cell.cols - 24));
          final required = painter.height + 24;
          final available = heights
              .sublist(cell.row, cell.row + cell.rows)
              .fold<double>(0, (a, b) => a + b);
          if (required > available) {
            for (var i = cell.row; i < cell.row + cell.rows; i++) {
              heights[i] += (required - available) / cell.rows;
            }
          }
          painter.dispose();
        }
        double offset(int row) =>
            heights.take(row).fold<double>(0, (a, b) => a + b);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (table['caption'] is String &&
                (table['caption'] as String).isNotEmpty)
              SelectableText(table['caption'] as String),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                height: offset(rows.length),
                child: Stack(
                  children: [
                    for (final cell in cells)
                      Positioned(
                        left: direction == TextDirection.ltr
                            ? unit * cell.col
                            : width - unit * (cell.col + cell.cols),
                        top: offset(cell.row),
                        width: unit * cell.cols,
                        height: offset(cell.row + cell.rows) - offset(cell.row),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cell.data['header'] == true
                                ? Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                : null,
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Semantics(
                            header: cell.data['header'] == true,
                            child: SelectableText(
                              '${cell.data['text'] ?? ''}',
                              style: cell.data['header'] == true
                                  ? base.copyWith(fontWeight: FontWeight.bold)
                                  : base,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
