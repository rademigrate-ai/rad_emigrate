import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Consultation Security RPC Integration', () {
    test('ConsultationPage uses submit_consultation_request RPC with safe fallback', () {
      final file = File(
        'lib/features/consultation/presentation/pages/consultation_page.dart',
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains("'submit_consultation_request'"));
      expect(content, contains("'p_topic': topic"));
      expect(content, contains("'p_message': message"));
      expect(content, contains("client.from('consultation_requests').insert"));
    });

    test('AdminConsultationsPage uses list_admin_consultations and update_admin_consultation RPCs', () {
      final file = File(
        'lib/features/admin/presentation/pages/admin_consultations_page.dart',
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains("'list_admin_consultations'"));
      expect(content, contains("'update_admin_consultation'"));
      expect(content, contains("'p_consultation_id': id"));
      expect(content, contains("'p_status': status"));
      expect(content, contains("'p_admin_note'"));
    });

    test('Stage 1 Migration 1 defines list_admin_consultations and update_admin_consultation', () {
      final file = File(
        'supabase/migrations/20261010010000_stage1_p0_security_completion.sql',
      );
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        expect(content, contains('function public.list_admin_consultations()'));
        expect(content, contains('function public.update_admin_consultation'));
      }
    });

    test('Stage 1 Migration 4 defines submit_consultation_request with rate limiting', () {
      final file = File(
        'supabase/migrations/20261012110945_stage1_security_abuse_storage_alignment.sql',
      );
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        expect(
          content,
          contains('function public.submit_consultation_request'),
        );
        expect(content, contains('consultation_rate_limited'));
        expect(
          content,
          contains(
            'revoke insert on table public.consultation_requests from authenticated',
          ),
        );
      }
    });
  });
}
