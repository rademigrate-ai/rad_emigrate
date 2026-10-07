/// Official research sources use public DNS names. Keep this validation in the
/// editor as well as the worker so an unusable source is not presented as saved.
Uri? parseResearchSourceUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.hasQuery ||
      uri.host.isEmpty ||
      (uri.hasPort && uri.port != 443)) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (!host.contains('.') ||
      RegExp(r'^[0-9]+$').hasMatch(host.split('.').last) ||
      host.endsWith('.local') ||
      host.endsWith('.localhost') ||
      host.endsWith('.internal') ||
      host == 'metadata.google.internal' ||
      RegExp(r'^[0-9.]+$').hasMatch(host) ||
      host
          .split('.')
          .any(
            (label) =>
                !RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$')
                    .hasMatch(label),
          )) {
    return null;
  }
  return uri;
}

/// Normalize the host and trailing path separators for supported page URLs.
String canonicalResearchSourceUrl(Uri uri) => Uri(
  scheme: 'https',
  host: uri.host.toLowerCase(),
  path: uri.path.replaceFirst(RegExp(r'/+$'), ''),
).toString();
