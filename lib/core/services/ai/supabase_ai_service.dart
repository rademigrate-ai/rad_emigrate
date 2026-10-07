import 'dart:ui';

import '../../../l10n/app_localizations.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../supabase/supabase_client.dart';
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
    try {
      final response = await _supabase.client.functions.invoke(
        'ai-orchestrator',
        body: {
          'action': 'chat',
          'scope': request.metadata['scope'] == 'admin' ? 'admin' : 'user',
          'session_id': request.conversationId,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw const FormatException('invalid_ai_response');
      }
      final map = data.cast<String, dynamic>();
      if (map['reply'] is String && (map['reply'] as String).isNotEmpty) {
        final sources = (map['sources'] as List? ?? const [])
            .whereType<Map>()
            .map((source) {
              final row = source.cast<String, dynamic>();
              return AiSource(
                title: row['title']?.toString() ?? row['url']?.toString() ?? '',
                url: row['url']?.toString(),
                authority: row['authority']?.toString(),
              );
            })
            .where((source) => source.title.isNotEmpty)
            .toList(growable: false);
        return AiResponse(
          text: map['reply'] as String,
          sources: sources,
          uncertain: map['uncertain'] == true,
          conversationId: request.conversationId,
        );
      }
      final code = (map['code'] ?? map['error'] ?? 'ai_failed').toString();
      return AiResponse(
        text: _messageForCode(code, request.locale),
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
        text: _messageForCode(code, request.locale),
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
        return l10n.aiCredentialRejected;
      case 'no_eligible_model':
      case 'provider_not_configured':
        return l10n.aiNoEligibleModel;
      case 'daily_limit_reached':
        return l10n.aiQuotaExhausted;
      case 'provider_rate_limited':
        return l10n.aiRateLimited;
      default:
        return l10n.aiRequestFailed;
    }
  }
}
