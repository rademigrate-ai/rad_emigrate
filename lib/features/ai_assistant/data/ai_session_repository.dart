import '../../../core/supabase/supabase_client.dart';

class AiSession {
  const AiSession({
    required this.id,
    required this.userId,
    required this.questionCount,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final int questionCount;
  final DateTime createdAt;
}

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

  Future<AiSession> createSession(String userId) async {
    final row = await _service.client
        .from('ai_sessions')
        .insert({'user_id': userId})
        .select()
        .single();
    return _sessionFromRow(row);
  }

  Future<List<AiSession>> listSessions(String userId) async {
    final rows = await _service.client
        .from('ai_sessions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => _sessionFromRow(row as Map<String, dynamic>))
        .toList();
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
    if (role == 'user') {
      final session = await _service.client
          .from('ai_sessions')
          .select('question_count')
          .eq('id', sessionId)
          .eq('user_id', userId)
          .single();
      final count = (session['question_count'] as int? ?? 0) + 1;
      await _service.client
          .from('ai_sessions')
          .update({'question_count': count})
          .eq('id', sessionId)
          .eq('user_id', userId);
    }
  }

  Future<List<AiSessionMessage>> history(String sessionId) async {
    final rows = await _service.client
        .from('ai_session_messages')
        .select()
        .eq('session_id', sessionId)
        .order('created_at');
    return (rows as List<dynamic>)
        .map((row) => _messageFromRow(row as Map<String, dynamic>))
        .toList();
  }

  AiSession _sessionFromRow(Map<String, dynamic> row) => AiSession(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    questionCount: row['question_count'] as int? ?? 0,
    createdAt: DateTime.parse(row['created_at'].toString()),
  );

  AiSessionMessage _messageFromRow(Map<String, dynamic> row) =>
      AiSessionMessage(
        id: row['id'] as String,
        sessionId: row['session_id'] as String,
        role: row['role'] as String,
        content: row['content'] as String,
        createdAt: DateTime.parse(row['created_at'].toString()),
      );
}
