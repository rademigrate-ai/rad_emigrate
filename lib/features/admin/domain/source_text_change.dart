import 'dart:typed_data';

enum TextChangeKind { unchanged, removed, inserted }

class TextChangeRun {
  const TextChangeRun(this.kind, this.text);
  final TextChangeKind kind;
  final String text;
}

/// Exact word/whitespace comparison. Large inputs use one bounded changed
/// passage after preserving common outer context; neither side is truncated.
List<TextChangeRun> sourceTextChanges(String before, String after) {
  if (before == after) return [TextChangeRun(TextChangeKind.unchanged, before)];
  final tokens = RegExp(r'\s+|[^\s]+', unicode: true);
  final a = tokens.allMatches(before).map((m) => m[0]!).toList();
  final b = tokens.allMatches(after).map((m) => m[0]!).toList();
  var prefix = 0;
  while (prefix < a.length && prefix < b.length && a[prefix] == b[prefix]) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < a.length - prefix &&
      suffix < b.length - prefix &&
      a[a.length - 1 - suffix] == b[b.length - 1 - suffix]) {
    suffix++;
  }
  final left = a.sublist(prefix, a.length - suffix);
  final right = b.sublist(prefix, b.length - suffix);
  final result = <TextChangeRun>[];
  void emit(TextChangeKind kind, String text) {
    if (text.isEmpty) return;
    if (result.isNotEmpty && result.last.kind == kind) {
      result[result.length - 1] = TextChangeRun(kind, result.last.text + text);
    } else {
      result.add(TextChangeRun(kind, text));
    }
  }

  emit(TextChangeKind.unchanged, a.take(prefix).join());
  if ((left.length + 1) * (right.length + 1) > 250000) {
    emit(TextChangeKind.removed, left.join());
    emit(TextChangeKind.inserted, right.join());
  } else {
    final lengths = List.generate(
      left.length + 1,
      (_) => Uint32List(right.length + 1),
    );
    for (var i = left.length - 1; i >= 0; i--) {
      for (var j = right.length - 1; j >= 0; j--) {
        lengths[i][j] = left[i] == right[j]
            ? 1 + lengths[i + 1][j + 1]
            : lengths[i + 1][j] >= lengths[i][j + 1]
            ? lengths[i + 1][j]
            : lengths[i][j + 1];
      }
    }
    var i = 0, j = 0;
    while (i < left.length || j < right.length) {
      if (i < left.length && j < right.length && left[i] == right[j]) {
        emit(TextChangeKind.unchanged, left[i++]);
        j++;
      } else if (i < left.length &&
          (j == right.length || lengths[i + 1][j] >= lengths[i][j + 1])) {
        emit(TextChangeKind.removed, left[i++]);
      } else {
        emit(TextChangeKind.inserted, right[j++]);
      }
    }
  }
  emit(
    TextChangeKind.unchanged,
    suffix == 0 ? '' : a.skip(a.length - suffix).join(),
  );
  return result;
}
