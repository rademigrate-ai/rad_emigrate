import 'rad_contract.dart';

/// Legacy table-shaped RPCs may emit PostgreSQL's explicit +00:00 UTC offset.
/// Normalize only that spelling, then validate the actual civil timestamp.
/// Missing or malformed server values must never become a local clock value.
DateTime requireServerTimestamp(Object? value) {
  if (value is! String) throw const FormatException('invalid_server_timestamp');
  final wire = value.endsWith('+00:00')
      ? '${value.substring(0, value.length - 6)}Z'
      : value;
  requireRadContract('Timestamp', wire);
  return DateTime.parse(wire);
}

String requireServerId(Object? value) {
  requireRadContract('UUID', value);
  return value as String;
}
