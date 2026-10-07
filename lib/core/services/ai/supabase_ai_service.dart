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
          if (request.metadata['guest_key'] is String &&
              (request.metadata['guest_key'] as String).isNotEmpty)
            'guest_key': request.metadata['guest_key'],
          if (request.metadata['locale'] is String)
            'locale': request.metadata['locale'],
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
      throw Exception(code);
    } catch (e) {
      rethrow;
    }
  }
}
