import 'dart:convert';

/// Text at the exact reviewed leaf, alongside the complete rich block preview.
/// Missing paths remain unavailable rather than comparing an unrelated leaf.
String? originalStructuredPatchText(
  Map<String, dynamic> block,
  Map<String, dynamic> patch,
) {
  if (patch['operation'] == 'add_after') return '';
  dynamic node = block['current_structure'] ?? block['original_structure'];
  if (node is! Map) return null;
  if (patch['operation'] == 'remove') {
    final parts = <String>[];
    void collect(dynamic value) {
      if (value is String) {
        parts.add(value);
      } else if (value is List) {
        for (final item in value) {
          collect(item);
        }
      } else if (value is Map) {
        for (final key in [
          'caption',
          'text',
          'items',
          'rows',
          'cells',
          'children',
        ]) {
          if (value.containsKey(key)) collect(value[key]);
        }
      }
    }

    collect(node);
    return parts.join('\n');
  }
  final path = patch['path'];
  if (path is! List || path.isEmpty) return null;
  for (final key in path) {
    if (key is! String) return null;
    if (node is Map) {
      node = node[key];
    } else if (node is List) {
      final index = int.tryParse(key);
      if (index == null || index < 0 || index >= node.length) return null;
      node = node[index];
    } else {
      return null;
    }
  }
  return node is String ? node : null;
}

/// Preview only. The server independently validates immutable hashes/evidence.
/// A deep copy keeps both source structures and the loaded baseline unchanged.
Map<String, dynamic> previewRichBlock(
  Map<String, dynamic> block,
  Map<String, dynamic> patch, {
  String? editedText,
}) {
  final result = jsonDecode(jsonEncode(block)) as Map<String, dynamic>;
  final text = editedText ?? patch['text'] as String? ?? '';
  if (patch['operation'] == 'add_after') {
    return {
      'id': patch['new_block_id'],
      'current_structure': {'type': 'paragraph', 'text': text},
      'provenance': <dynamic>[],
    };
  }
  if (patch['operation'] == 'remove') return result;
  final structure = jsonDecode(
    jsonEncode(result['current_structure'] ?? result['original_structure']),
  ) as Map<String, dynamic>;
  final path = (patch['path'] as List).cast<String>();
  if (path.isEmpty) throw const FormatException('Empty text path');
  dynamic node = structure;
  for (final key in path.take(path.length - 1)) {
    node = node is List ? node[int.parse(key)] : (node as Map)[key];
  }
  if (node is List) {
    node[int.parse(path.last)] = text;
  } else {
    (node as Map)[path.last] = text;
  }
  result['current_structure'] = structure;
  return result;
}
