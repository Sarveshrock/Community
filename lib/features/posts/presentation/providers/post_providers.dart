import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/supabase_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/post_repository_impl.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';

export '../../domain/entities/post.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepositoryImpl(supabase);
});

const _pageSize = AppConstants.defaultPageSize;

class PostsFeedState {
  const PostsFeedState({
    this.posts = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
    this.category,
  });

  final List<Post> posts;
  final bool hasMore;
  final bool isLoadingMore;
  final String? category;

  PostsFeedState copyWith(
      {List<Post>? posts,
      bool? hasMore,
      bool? isLoadingMore,
      String? category}) {
    return PostsFeedState(
      posts: posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      category: category ?? this.category,
    );
  }
}

/// The global feed, paginated. A "Load more"/infinite-scroll controller —
/// the shape this repeats elsewhere in the app (plain `.range()` calls,
/// e.g. `HackathonRepositoryImpl.listHackathons`) doesn't currently
/// accumulate pages anywhere else, so this is the first cumulative-list
/// controller in the codebase; kept deliberately plain (no new state
/// library) to match everything else here.
class PostsFeedNotifier extends AsyncNotifier<PostsFeedState> {
  @override
  Future<PostsFeedState> build() async {
    final posts =
        await ref.read(postRepositoryProvider).listFeed(limit: _pageSize);
    return PostsFeedState(posts: posts, hasMore: posts.length == _pageSize);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final more = await ref.read(postRepositoryProvider).listFeed(
            limit: _pageSize,
            offset: current.posts.length,
            category: current.category,
          );
      state = AsyncData(current.copyWith(
        posts: [...current.posts, ...more],
        hasMore: more.length == _pageSize,
        isLoadingMore: false,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> setCategory(String? category) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final posts = await ref
          .read(postRepositoryProvider)
          .listFeed(limit: _pageSize, category: category);
      return PostsFeedState(
          posts: posts, hasMore: posts.length == _pageSize, category: category);
    });
  }

  Future<void> refresh() async {
    final category = state.valueOrNull?.category;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final posts = await ref
          .read(postRepositoryProvider)
          .listFeed(limit: _pageSize, category: category);
      return PostsFeedState(
          posts: posts, hasMore: posts.length == _pageSize, category: category);
    });
  }
}

final postsFeedProvider =
    AsyncNotifierProvider<PostsFeedNotifier, PostsFeedState>(
        PostsFeedNotifier.new);

final postDetailProvider = FutureProvider.family<Post, String>((ref, id) {
  return ref.watch(postRepositoryProvider).getPost(id);
});

/// First page of a specific author's posts — backs the Profile "Posts"
/// section. No infinite scroll there (a profile's own post count is small
/// enough that a single page is fine; the dedicated feed is where
/// pagination actually matters).
final authorPostsProvider =
    FutureProvider.family<List<Post>, String>((ref, authorId) {
  return ref.watch(postRepositoryProvider).listByAuthor(authorId);
});

/// Whether the caller has liked a post — seeds `PostCard`'s local like
/// toggle; the toggle itself then updates local state instantly rather
/// than re-watching this on every tap (see `PostCard`).
final isPostLikedByMeProvider =
    FutureProvider.family<bool, String>((ref, postId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Future.value(false);
  return ref.watch(postRepositoryProvider).isLikedByMe(postId);
});

final postCommentsProvider =
    FutureProvider.family<List<PostComment>, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).listComments(postId);
});

class PostController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createPost({
    String? content,
    String? category,
    List<(String, PostMediaType)> mediaItems = const [],
    List<String> linkUrls = const [],
    List<String> mentionedProfileIds = const [],
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(postRepositoryProvider).createPost(
            content: content,
            category: category,
            mediaItems: mediaItems,
            linkUrls: linkUrls,
            mentionedProfileIds: mentionedProfileIds,
          );
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
    state = const AsyncData(null);
    ref.invalidate(postsFeedProvider);
    final myId = ref.read(authStateProvider).valueOrNull?.id;
    if (myId != null) ref.invalidate(authorPostsProvider(myId));
    return true;
  }

  Future<bool> deletePost(String postId, {String? authorId}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(postRepositoryProvider).deletePost(postId));
    state = result;
    if (!result.hasError) {
      ref.invalidate(postsFeedProvider);
      ref.invalidate(postDetailProvider(postId));
      if (authorId != null) ref.invalidate(authorPostsProvider(authorId));
    }
    return !result.hasError;
  }

  /// Returns the uploaded storage path, or null on failure (caller shows
  /// its own error snack — mirrors `MessageController`'s attachment flow).
  Future<String?> uploadMedia(
      {required List<int> bytes, required String fileName}) async {
    final myId = ref.read(authStateProvider).valueOrNull?.id;
    if (myId == null) return null;
    try {
      return await ref
          .read(postRepositoryProvider)
          .uploadMedia(myId, bytes: bytes, fileName: fileName);
    } catch (_) {
      return null;
    }
  }

  /// Like/unlike. Deliberately does *not* invalidate the feed/profile list
  /// providers — `PostCard` already updates its own like count locally and
  /// instantly, and invalidating a paginated `postsFeedProvider` would
  /// reset its loaded pages/scroll position for a count bump nobody but
  /// this card needs to see immediately. `posts.like_count` itself is kept
  /// accurate server-side by a DB trigger (0032) regardless.
  Future<bool> setLiked(String postId, {required bool liked}) async {
    try {
      await ref.read(postRepositoryProvider).setLiked(postId, liked: liked);
      ref.invalidate(isPostLikedByMeProvider(postId));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<PostComment?> addComment(String postId, String content) async {
    try {
      final comment =
          await ref.read(postRepositoryProvider).addComment(postId, content);
      ref.invalidate(postCommentsProvider(postId));
      return comment;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteComment(String commentId, String postId) async {
    try {
      await ref.read(postRepositoryProvider).deleteComment(commentId);
      ref.invalidate(postCommentsProvider(postId));
      return true;
    } catch (_) {
      return false;
    }
  }
}

final postControllerProvider =
    AsyncNotifierProvider<PostController, void>(PostController.new);
