import '../entities/post.dart';

abstract class PostRepository {
  /// The global feed, newest first. [category] filters to one dev-topic tag
  /// when set (spec: keep the feed tech/developer-focused via filterable
  /// categories, not a generic algorithmic feed).
  Future<List<Post>> listFeed(
      {int limit = 20, int offset = 0, String? category});

  Future<Post> getPost(String id);

  Future<List<Post>> listByAuthor(String authorId,
      {int limit = 20, int offset = 0});

  /// Creates a post plus its media/link/mention rows. [mediaItems] are
  /// storage paths already uploaded via [uploadMedia]. Runs as a few
  /// sequential inserts (same pattern as
  /// `HackathonRepositoryImpl.createTeamRequirement`) rather than a single
  /// RPC — every table involved already has RLS scoped to `author_id =
  /// auth.uid()`, so there's no privilege-escalation risk in doing it
  /// client-side across multiple statements.
  Future<Post> createPost({
    String? content,
    String? category,
    List<(String storagePath, PostMediaType type)> mediaItems,
    List<String> linkUrls,
    List<String> mentionedProfileIds,
  });

  /// Soft delete (sets `deleted_at`) — mirrors `community_posts`.
  Future<void> deletePost(String postId);

  /// Uploads to the `post-media` bucket under `<authorId>/<unique>_<fileName>`
  /// and returns that storage path (bucket is public read; RLS scopes
  /// writes to the uploader's own folder).
  Future<String> uploadMedia(String authorId,
      {required List<int> bytes, required String fileName});

  /// Public URL for a `post-media` storage path (public bucket, unlike
  /// `chat-attachments` — no signed URL needed).
  String getMediaPublicUrl(String storagePath);

  /// Whether the caller has liked [postId].
  Future<bool> isLikedByMe(String postId);

  /// Like/unlike — `posts.like_count` is kept in sync by a DB trigger
  /// (0032), never trusted from the client.
  Future<void> setLiked(String postId, {required bool liked});

  Future<List<PostComment>> listComments(String postId, {int limit = 50});

  Future<PostComment> addComment(String postId, String content);

  /// Soft delete (sets `deleted_at`) — mirrors [deletePost].
  Future<void> deleteComment(String commentId);
}
