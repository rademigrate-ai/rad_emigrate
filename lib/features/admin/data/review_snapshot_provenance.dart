/// Only surface a canonical source link after verifying the captured
/// research snapshot points to a non-removed HTTPS document. This is evidence
/// for human review, NOT a source-approval or publication decision.
String? verifiedReviewSnapshotUrl({
  required Object? canonicalUrl,
  required Object? httpStatus,
  required Object? removedAt,
}) {
  if (canonicalUrl is! String || removedAt != null) return null;
  if (httpStatus is! int || httpStatus < 200 || httpStatus >= 300) {
    return null;
  }

  final value = canonicalUrl.trim();
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      !uri.host.contains('.') ||
      RegExp(r'^[0-9.]+$').hasMatch(uri.host) ||
      uri.host.contains(':') ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return value;
}
