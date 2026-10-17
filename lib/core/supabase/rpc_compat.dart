import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// Evaluates whether an exception positively indicates that the requested
/// RPC function is not installed on the Supabase/PostgREST backend (e.g. pre-migration).
///
/// Strictly scopes the fallback condition to missing function definitions:
/// - PostgREST schema cache miss: code 'PGRST202'
/// - PostgreSQL undefined function: code '42883'
/// - Explicit "could not find the function" message pattern
///
/// NEVER returns true for:
/// - Permission / authorization errors ('42501')
/// - Validation / parameter errors ('22023')
/// - User rate-limit or custom exceptions ('P0001')
/// - Target not found ('P0002')
/// - Network errors, SocketExceptions, TimeoutExceptions, or ClientExceptions
/// - Malformed responses or type cast failures
bool isRpcMissingException(Object error) {
  if (error is PostgrestException) {
    final code = error.code?.trim().toUpperCase();
    if (code != null && code.isNotEmpty) {
      // An explicit authorization, rate-limit or validation error must never
      // be reclassified as a missing-RPC error based on its message body.
      return code == 'PGRST202' || code == '42883';
    }
    final message = error.message.toLowerCase();
    if (message.contains('could not find the function') &&
        message.contains('in the schema cache')) {
      return true;
    }
  }
  return false;
}
