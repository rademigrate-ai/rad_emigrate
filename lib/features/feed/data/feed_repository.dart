import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/supabase_providers.dart';

class FeedEntry {
  const FeedEntry({
    required this.id,
    required this.slug,
    required this.category,
    required this.title,
    required this.summary,
    required this.saved,
    this.sourceUrl,
    this.publishedAt,
  });

  final String id;
  final String slug;
  final String category;
  final String title;
  final String summary;
  final bool saved;
  final String? sourceUrl;
  final DateTime? publishedAt;
}

class FeedRepository {
  const FeedRepository(this._supabase);

  final SupabaseClientService _supabase;

  Future<List<FeedEntry>> load(String locale) async {
    if (!_supabase.isInitialized) return const [];
    final client = _supabase.client;
    final rows = await client
        .from('feed_items')
        .select(
          'id,slug,category,source_url,published_at,'
          'feed_item_localizations(locale,title,summary)',
        )
        .order('published_at', ascending: false);
    final userId = client.auth.currentUser?.id;
    final saved = <String>{};
    if (userId != null) {
      final savedRows = await client
          .from('saved_feed_items')
          .select('feed_item_id')
          .eq('user_id', userId);
      saved.addAll(savedRows.map((row) => row['feed_item_id'] as String));
    }
    return rows.map((row) {
      final localizations = (row['feed_item_localizations'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      Map<String, dynamic>? text;
      for (final item in localizations) {
        if (item['locale'] == locale) text = item;
      }
      if (text == null && localizations.isNotEmpty) {
        text = localizations.first;
      }
      return FeedEntry(
        id: row['id'] as String,
        slug: row['slug'] as String,
        category: row['category'] as String,
        title: text?['title'] as String? ?? row['slug'] as String,
        summary: text?['summary'] as String? ?? '',
        sourceUrl: row['source_url'] as String?,
        publishedAt: DateTime.tryParse(row['published_at'] as String? ?? ''),
        saved: saved.contains(row['id']),
      );
    }).toList();
  }

  Future<void> setSaved(String itemId, bool value) async {
    final client = _supabase.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Authentication required.');
    if (value) {
      await client.from('saved_feed_items').upsert({
        'user_id': userId,
        'feed_item_id': itemId,
      });
    } else {
      await client
          .from('saved_feed_items')
          .delete()
          .eq('user_id', userId)
          .eq('feed_item_id', itemId);
    }
  }

  Future<void> markRead(String itemId) async {
    final client = _supabase.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client.from('feed_item_reads').upsert({
      'user_id': userId,
      'feed_item_id': itemId,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(ref.watch(supabaseClientServiceProvider)),
);

final feedProvider = FutureProvider.autoDispose.family<List<FeedEntry>, String>(
  (ref, locale) => ref.watch(feedRepositoryProvider).load(locale),
);
