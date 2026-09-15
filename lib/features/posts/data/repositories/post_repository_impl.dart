import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';

class PostRepositoryImpl implements PostRepository {
  PostRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _select =
      '*, author:profiles!posts_author_id_fkey(full_name, avatar_url, current_role), '
      'post_media(id, media_type, storage_path, sort_order), '
      'post_links(id, url, domain), '
      'post_mentions(mentioned_profile_id, profiles(full_name, avatar_url))';

  @override
  Future<List<Post>> listFeed(
      {int limit = 20, int offset = 0, String? category}) async {
    try {
      var query = _client.from(Tables.posts).select(_select);
      if (category != null) query = query.eq('category', category);
      final data = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Post> getPost(String id) async {
    try {
      final data = await _client
          .from(Tables.posts)
          .select(_select)
          .eq('id', id)
          .single();
      return Post.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<Post>> listByAuthor(String authorId,
      {int limit = 20, int offset = 0}) async {
    try {
      final data = await _client
          .from(Tables.posts)
          .select(_select)
          .eq('author_id', authorId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Post> createPost({
    String? content,
    String? category,
    List<(String storagePath, PostMediaType type)> mediaItems = const [],
    List<String> linkUrls = const [],
    List<String> mentionedProfileIds = const [],
  }) async {
    try {
      final myId = _client.auth.currentUser!.id;
      final inserted = await _client
          .from(Tables.posts)
          .insert({
            'author_id': myId,
            if (content != null && content.isNotEmpty) 'content': content,
            if (category != null) 'category': category,
          })
          .select()
          .single();
      final postId = inserted['id'] as String;

      if (mediaItems.isNotEmpty) {
        await _client.from(Tables.postMedia).insert([
          for (var i = 0; i < mediaItems.length; i++)
            {
              'post_id': postId,
              'media_type': mediaItems[i].$2.value,
              'storage_path': mediaItems[i].$1,
              'sort_order': i,
            },
        ]);
      }

      if (linkUrls.isNotEmpty) {
        await _client.from(Tables.postLinks).insert([
          for (final url in linkUrls)
            {'post_id': postId, 'url': url, 'domain': Uri.tryParse(url)?.host},
        ]);
      }

      if (mentionedProfileIds.isNotEmpty) {
        await _client.from(Tables.postMentions).insert([
          for (final profileId in mentionedProfileIds)
            {'post_id': postId, 'mentioned_profile_id': profileId},
        ]);
      }

      return await getPost(postId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    try {
      await _client.from(Tables.posts).update(
          {'deleted_at': DateTime.now().toIso8601String()}).eq('id', postId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> uploadMedia(String authorId,
      {required List<int> bytes, required String fileName}) async {
    try {
      final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final path =
          '$authorId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await _client.storage
          .from(StorageBuckets.postMedia)
          .uploadBinary(path, Uint8List.fromList(bytes));
      return path;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  String getMediaPublicUrl(String storagePath) {
    return _client.storage
        .from(StorageBuckets.postMedia)
        .getPublicUrl(storagePath);
  }

  @override
  Future<bool> isLikedByMe(String postId) async {
    try {
      final myId = _client.auth.currentUser?.id;
      if (myId == null) return false;
      final data = await _client
          .from(Tables.postLikes)
          .select('post_id')
          .eq('post_id', postId)
          .eq('profile_id', myId)
          .maybeSingle();
      return data != null;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> setLiked(String postId, {required bool liked}) async {
    try {
      final myId = _client.auth.currentUser!.id;
      if (liked) {
        await _client.from(Tables.postLikes).upsert(
          {'post_id': postId, 'profile_id': myId},
          onConflict: 'post_id,profile_id',
        );
      } else {
        await _client
            .from(Tables.postLikes)
            .delete()
            .eq('post_id', postId)
            .eq('profile_id', myId);
      }
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<PostComment>> listComments(String postId, {int limit = 50}) async {
    try {
      final data = await _client
          .from(Tables.postComments)
          .select('*, author:profiles!post_comments_author_id_fkey(full_name, avatar_url)')
          .eq('post_id', postId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: true)
          .limit(limit);
      return (data as List)
          .map((e) => PostComment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<PostComment> addComment(String postId, String content) async {
    try {
      final myId = _client.auth.currentUser!.id;
      final inserted = await _client
          .from(Tables.postComments)
          .insert({'post_id': postId, 'author_id': myId, 'content': content})
          .select('*, author:profiles!post_comments_author_id_fkey(full_name, avatar_url)')
          .single();
      return PostComment.fromJson(inserted);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> deleteComment(String commentId) async {
    try {
      await _client
          .from(Tables.postComments)
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', commentId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
