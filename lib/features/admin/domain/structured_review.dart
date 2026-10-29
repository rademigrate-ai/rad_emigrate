import 'dart:convert';

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
