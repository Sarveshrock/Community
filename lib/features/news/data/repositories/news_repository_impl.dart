import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/news_comment.dart';
import '../../domain/entities/news_item.dart';
import '../../domain/repositories/news_repository.dart';

class NewsRepositoryImpl implements NewsRepository {
  NewsRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<NewsItem>> listNews({
    String? category,
    bool trendingOnly = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      var query = _client.from(Tables.newsItems).select();
      if (category != null) query = query.eq('category', category);
      if (trendingOnly) query = query.eq('is_trending', true);

      final offset = (page - 1) * pageSize;
      final data = await query
          .order('final_score', ascending: false)
          .order('published_at', ascending: false)
          .range(offset, offset + pageSize - 1);

      final items = (data as List)
          .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
          .toList();

      final hidden = await listHiddenUrls();
      return items.where((i) => !hidden.contains(i.url)).toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> saveNews(NewsItem item) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client.from(Tables.savedNews).upsert({
        'profile_id': myId,
        'article_url': item.url,
        'title': item.title,
        'summary': item.description,
        'image_url': item.imageUrl,
        'source_name': item.source,
        'published_at': item.publishedAt?.toIso8601String(),
        'category': item.category,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> unsaveNews(String articleUrl) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client
          .from(Tables.savedNews)
          .delete()
          .eq('profile_id', myId)
          .eq('article_url', articleUrl);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> hideNews(String articleUrl) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client
          .from(Tables.hiddenNews)
          .insert({'profile_id': myId, 'article_url': articleUrl});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<NewsItem>> listSaved() async {
    try {
      final myId = _client.auth.currentUser?.id;
      if (myId == null) return [];
      final data = await _client
          .from(Tables.savedNews)
          .select()
          .eq('profile_id', myId)
          .order('saved_at', ascending: false);
      return (data as List)
          .map((e) => _fromSavedRow(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Set<String>> listHiddenUrls() async {
    try {
      final myId = _client.auth.currentUser?.id;
      if (myId == null) return {};
      final data = await _client
          .from(Tables.hiddenNews)
          .select('article_url')
          .eq('profile_id', myId);
      return (data as List).map((e) => e['article_url'] as String).toSet();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  static const _commentSelect =
      '*, author:profiles!news_comments_author_id_fkey(full_name, avatar_url), '
      'mentioned:profiles!news_comments_mentioned_profile_id_fkey(full_name)';

  @override
  Future<List<NewsComment>> listComments(String articleUrl) async {
    try {
      final data = await _client
          .from(Tables.newsComments)
          .select(_commentSelect)
          .eq('article_url', articleUrl)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: true);
      return (data as List)
          .map((e) => NewsComment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<NewsComment> addComment(
    String articleUrl,
    String content, {
    String? parentCommentId,
    String? mentionedProfileId,
  }) async {
    try {
      final myId = _client.auth.currentUser!.id;
      final inserted = await _client
          .from(Tables.newsComments)
          .insert({
            'article_url': articleUrl,
            'author_id': myId,
            'content': content,
            'parent_comment_id': parentCommentId,
            'mentioned_profile_id': mentionedProfileId,
          })
          .select(_commentSelect)
          .single();
      return NewsComment.fromJson(inserted);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> deleteComment(String commentId) async {
    try {
      await _client
          .from(Tables.newsComments)
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', commentId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  NewsItem _fromSavedRow(Map<String, dynamic> row) => NewsItem(
        id: row['article_url'] as String,
        url: row['article_url'] as String,
        title: row['title'] as String,
        description: row['summary'] as String?,
        imageUrl: row['image_url'] as String?,
        publishedAt: row['published_at'] != null
            ? DateTime.tryParse(row['published_at'] as String)
            : null,
        source: row['source_name'] as String?,
        category: row['category'] as String?,
      );
}
