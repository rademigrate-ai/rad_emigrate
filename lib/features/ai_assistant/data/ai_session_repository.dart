import '../../../core/supabase/supabase_client.dart';

class AiSessionMessage {
  const AiSessionMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final String role;
  final String content;
  final DateTime createdAt;
}

class AiSessionRepository {
  AiSessionRepository(this._service);

  final SupabaseClientService _service;

  Future<String> createSession(String userId) async {
    final row = await _service.client
        .from('ai_sessions')
        .insert({'user_id': userId})
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> saveMessage({
    required String sessionId,
    required String userId,
    required String role,
    required String content,
  }) async {
    await _service.client.from('ai_session_messages').insert({
      'session_id': sessionId,
      'user_id': userId,
      'role': role,
      'content': content,
    });
  }

  Future<List<AiSessionMessage>> history(String sessionId) async {
    final rows = await _service.client
        .from('ai_session_messages')
        .select()
        .eq('session_id', sessionId)
        .order('created_at');
    return (rows as List<dynamic>)
        .map(
          (row) => AiSessionMessage(
            id: row['id'] as String,
            sessionId: row['session_id'] as String,
            role: row['role'] as String,
            content: row['content'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }
}
