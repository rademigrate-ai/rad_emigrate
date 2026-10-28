import 'dart:math';
import 'dart:ui';

import '../../../l10n/app_localizations.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../supabase/supabase_client.dart';
import '../../supabase/rad_contract.dart';
import 'ai_guest_identity.dart';
import 'ai_request.dart';
import 'ai_response.dart';
import 'ai_service.dart';

class SupabaseAiService implements AiService {
  const SupabaseAiService(this._supabase);

  final SupabaseClientService _supabase;

  /// RFC-4122 style UUID v4 for AI request keys (no extra dependency).
  static String _newRequestKey() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

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
    final owner = session?.user.id;
    var sessionInvalidated = false;
    final authSubscription = _supabase.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.event == AuthChangeEvent.signedOut ||
          state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.passwordRecovery ||
          state.session?.user.id != owner) {
        sessionInvalidated = true;
      }
    }, onError: (Object error, StackTrace stack) => sessionInvalidated = true);
    bool sameOwner() =>
        !sessionInvalidated &&
        _supabase.client.auth.currentSession?.user.id == owner;
    AiResponse changedSession() => AiResponse(
      text: _messageForCode('session_changed', request.locale),
      uncertain: true,
      errorCode: 'session_changed',
    );
    final locale =
        request.locale ??
        (request.metadata['locale'] is String
            ? request.metadata['locale'] as String
            : null);

    try {
      final isAuthed = session != null && session.user.id.isNotEmpty;
      String? guestKey = request.metadata['guest_key'];
      if (!isAuthed && (guestKey == null || guestKey.isEmpty)) {
        guestKey = await AiGuestIdentity.getOrCreate();
      }

      // RAD AI contract version 1: numeric header, UUID request_key, closed body.
      final metaKey = request.metadata['request_key']?.toString();
      final requestKey =
          (metaKey != null &&
              RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
                caseSensitive: false,
              ).hasMatch(metaKey))
          ? metaKey.toLowerCase()
          : _newRequestKey();

      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      String? cleanUuid(String? val) {
        if (val == null) return null;
        final trimmed = val.trim().toLowerCase();
        return uuidRegex.hasMatch(trimmed) ? trimmed : null;
      }

      final cleanLocale =
          (locale != null && locale.toLowerCase().startsWith('fa'))
          ? 'fa'
          : 'en';
      final cleanGuestKey =
          (guestKey != null &&
              guestKey.trim().length >= 16 &&
              guestKey.trim().length <= 128)
          ? guestKey.trim()
          : null;
      final cleanScopes = request.authorizedDataScopes
          .where(
            (scope) =>
                scope == 'profile' ||
                scope == 'cases' ||
                scope == 'notifications',
          )
          .toSet()
          .toList(growable: false);
      final cleanContext = {
        'article_id': cleanUuid(request.context['article_id']),
        'section_id': cleanUuid(request.context['section_id']),
        'case_id': cleanUuid(request.context['case_id']),
      };

      if (!sameOwner()) return changedSession();
      final response = await _supabase.client.functions.invoke(
        'ai-orchestrator',
        headers: {
          'x-rad-contract-version': '1',
          'x-rad-request-key': requestKey,
          'x-rad-modality': 'text',
        },
        body: {
          'action': 'chat',
          'request_key': requestKey,
          'scope': request.metadata['scope'] == 'admin' ? 'admin' : 'user',
          'session_id': cleanUuid(request.conversationId),
          'guest_key': cleanGuestKey,
          'locale': cleanLocale,
          'authorized_data_scopes': cleanScopes,
          'context': cleanContext,
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
      if (!sameOwner()) return changedSession();
      final data = response.data;
      requireRadContract('ai_orchestrator_response', data);
      final map = (data as Map).cast<String, dynamic>();
      final payload = (map['data'] as Map).cast<String, dynamic>();
      final reply = payload['reply'] as String?;
      if (reply != null && reply.isNotEmpty) {
        final rawSources = payload['citations'] as List;
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
            evidenceState != 'sufficient' ||
            payload['refused'] == true ||
            payload['truncated'] == true;

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
      if (!sameOwner()) return changedSession();
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
    } catch (e) {
      if (!sameOwner()) return changedSession();
      final code = e is FormatException ? 'invalid_ai_response' : 'ai_failed';
      return AiResponse(
        text: _messageForCode(code, locale),
        uncertain: true,
        errorCode: code,
        conversationId: request.conversationId,
      );
    } finally {
      await authSubscription.cancel();
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
      case 'insufficient':
        return l10n.aiInsufficientEvidence;
      default:
        return l10n.aiRequestFailed;
    }
  }
}
