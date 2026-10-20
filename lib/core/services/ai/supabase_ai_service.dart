import 'dart:ui';

import '../../../l10n/app_localizations.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../supabase/supabase_client.dart';
import 'ai_guest_identity.dart';
import 'ai_request.dart';
import 'ai_response.dart';
import 'ai_service.dart';

class SupabaseAiService implements AiService {
  const SupabaseAiService(this._supabase);

  final SupabaseClientService _supabase;

  @override
  bool get isAvailable => _supabase.isInitialized;

  @override
  Future<String> ask(String prompt) async =>
      (await complete(AiRequest(prompt: prompt))).text;

  @override
  Future<AiResponse> complete(AiRequest request) async {
    if (!_supabase.isInitialized) {
      return UnavailableAiService().complete(request);
    }
    final prompt = request.prompt.trim();
    if (prompt.isEmpty) {
      return const AiResponse(text: '', uncertain: true);
    }

    // Guest key when not authenticated (server enforces 5-question limit).
    final session = _supabase.client.auth.currentSession;
    final isAuthed = session != null && session.user.id.isNotEmpty;
    String? guestKey = request.metadata['guest_key'];
    if (!isAuthed && (guestKey == null || guestKey.isEmpty)) {
      guestKey = await AiGuestIdentity.getOrCreate();
    }

    final locale =
        request.locale ??
        (request.metadata['locale'] is String
            ? request.metadata['locale']
            : null);

    try {
      // RAD AI v1 text-only contract: version + idempotency + explicit scopes.
      final requestKey =
          request.metadata['request_key']?.toString() ??
          'ai-${DateTime.now().toUtc().microsecondsSinceEpoch}';
      final authorizedScopes = request.metadata['authorized_data_scopes'];
      final response = await _supabase.client.functions.invoke(
        'ai-orchestrator',
        headers: {
          'x-rad-contract-version': 'v1',
          'x-rad-request-key': requestKey,
          'x-rad-modality': 'text',
        },
        body: {
          'action': 'chat',
          'contract_version': 'v1',
          'request_key': requestKey,
          'modality': 'text',
          'scope': request.metadata['scope'] == 'admin' ? 'admin' : 'user',
          'session_id': request.conversationId,
          if (guestKey != null && guestKey.isNotEmpty) 'guest_key': guestKey,
          if (locale != null && locale.isNotEmpty) 'locale': locale,
          if (authorizedScopes is List && authorizedScopes.isNotEmpty)
            'authorized_data_scopes': authorizedScopes,
          'messages': [
            ...request.history.map(
              (message) => {
                'role': message.isUser ? 'user' : 'assistant',
                'content': message.text,
              },
            ),
            {'role': 'user', 'content': prompt},
          ],
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw const FormatException('invalid_ai_response');
      }
      final map = data.cast<String, dynamic>();
      final payload = map['data'] is Map
          ? (map['data'] as Map).cast<String, dynamic>()
          : map;
      final reply = payload['reply'] as String?;
      if (reply != null && reply.isNotEmpty) {
        final rawSources =
            payload['citations'] as List? ??
            payload['sources'] as List? ??
            const [];
        final sources = rawSources
            .whereType<Map>()
            .map((source) {
              final row = source.cast<String, dynamic>();
              final title =
                  row['title']?.toString() ?? row['url']?.toString() ?? '';
              final url = row['url']?.toString();
              final authority = row['authority']?.toString();
              return AiSource(
                title: title.isNotEmpty ? title : (url ?? 'مرجع رسمی'),
                url: url,
                authority: authority,
              );
            })
            .where((source) => source.title.isNotEmpty)
            .toList(growable: false);

        final evidenceState = payload['evidence_state']?.toString();
        final isUncertain =
            payload['uncertain'] == true ||
            evidenceState == 'unavailable' ||
            evidenceState == 'insufficient' ||
            evidenceState == 'conflicting';

        return AiResponse(
          text: reply,
          sources: sources,
          uncertain: isUncertain,
          conversationId:
              payload['session_id']?.toString() ?? request.conversationId,
        );
      }
      final code =
          (payload['code'] ??
                  payload['error'] ??
                  map['code'] ??
                  map['error'] ??
                  'ai_failed')
              .toString();
      return AiResponse(
        text: _messageForCode(code, locale),
        uncertain: true,
        errorCode: code,
        conversationId: request.conversationId,
      );
    } on FunctionException catch (e) {
      final details = e.details;
      String code = 'ai_failed';
      if (details is Map) {
        code = (details['code'] ?? details['error'] ?? code).toString();
      } else if (e.reasonPhrase != null && e.reasonPhrase!.isNotEmpty) {
        code = e.reasonPhrase!;
      }
      return AiResponse(
        text: _messageForCode(code, locale),
        uncertain: true,
        errorCode: code,
        conversationId: request.conversationId,
      );
    }
  }

  static String _messageForCode(String code, String? locale) {
    final l10n = lookupAppLocalizations(Locale(locale == 'fa' ? 'fa' : 'en'));
    switch (code) {
      case 'provider_unauthorized':
      case 'provider_auth_failed':
      case 'unauthorized':
        return l10n.aiCredentialRejected;
      case 'no_eligible_model':
      case 'provider_not_configured':
        return l10n.aiNoEligibleModel;
      case 'daily_limit_reached':
      case 'quota_exhausted':
      case 'anonymous_quota_exceeded':
      case 'authentication_required':
        return l10n.aiQuotaExhausted;
      case 'provider_rate_limited':
      case 'rate_limit_exceeded':
        return l10n.aiRateLimited;
      case 'insufficient_evidence':
      case 'empty_evidence':
      case 'stale_evidence':
      case 'unavailable_evidence':
        return 'شواهد رسمی و مستندات کافی برای این درخواست در پایگاه داده یافت نشد.';
      default:
        return l10n.aiRequestFailed;
    }
  }
}
