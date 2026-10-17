import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/supabase/rpc_compat.dart';

void main() {
  group('isRpcMissingException - Narrow Capability Detection', () {
    test('identifies PGRST202 (schema cache miss) as missing RPC', () {
      final error = const PostgrestException(
        message: 'Could not find the function public.submit_consultation_request in the schema cache',
        code: 'PGRST202',
      );
      expect(isRpcMissingException(error), isTrue);
    });

    test('identifies 42883 (undefined_function) as missing RPC', () {
      final error = const PostgrestException(
        message: 'function public.list_admin_consultations() does not exist',
        code: '42883',
      );
      expect(isRpcMissingException(error), isTrue);
    });

    test(
      'identifies descriptive function not found message without explicit code',
      () {
        final error = const PostgrestException(
          message:
              'Could not find the function public.test_rpc in the schema cache',
        );
        expect(isRpcMissingException(error), isTrue);
      },
    );

    test('REJECTS permission denied (42501)', () {
      final error = const PostgrestException(
        message: 'permission denied for function update_admin_consultation',
        code: '42501',
      );
      expect(isRpcMissingException(error), isFalse);
    });

    test('REJECTS validation error (22023)', () {
      final error = const PostgrestException(
        message: 'invalid consultation status',
        code: '22023',
      );
      expect(isRpcMissingException(error), isFalse);
    });

    test('REJECTS user rate limit / custom error (P0001)', () {
      final error = const PostgrestException(
        message: 'consultation_rate_limited',
        code: 'P0001',
      );
      expect(isRpcMissingException(error), isFalse);
    });

    test('REJECTS row not found (P0002)', () {
      final error = const PostgrestException(
        message: 'consultation not found',
        code: 'P0002',
      );
      expect(isRpcMissingException(error), isFalse);
    });

    test('REJECTS network and socket exceptions', () {
      final error = const SocketException('Connection refused');
      expect(isRpcMissingException(error), isFalse);
    });

    test('REJECTS timeout exceptions', () {
      final error = TimeoutException('Operation timed out');
      expect(isRpcMissingException(error), isFalse);
    });

    test('REJECTS format exceptions and type errors', () {
      final error = const FormatException('Invalid JSON payload');
      expect(isRpcMissingException(error), isFalse);
    });
  });
}
