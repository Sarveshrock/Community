enum PostMediaType { image, video }

extension PostMediaTypeX on PostMediaType {
  String get value => name;
  static PostMediaType fromValue(String? value) => PostMediaType.values
      .firstWhere((e) => e.value == value, orElse: () => PostMediaType.image);
}

class PostMedia {
  const PostMedia(
      {required this.id,
      required this.type,
      required this.storagePath,
      this.sortOrder = 0});

  final String id;
  final PostMediaType type;
  final String storagePath;
  final int sortOrder;

  factory PostMedia.fromJson(Map<String, dynamic> json) => PostMedia(
        id: json['id'] as String,
        type: PostMediaTypeX.fromValue(json['media_type'] as String?),
        storagePath: json['storage_path'] as String,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );
}

class PostLink {
  const PostLink({required this.id, required this.url, this.domain});

  final String id;
  final String url;
  final String? domain;

  factory PostLink.fromJson(Map<String, dynamic> json) => PostLink(
        id: json['id'] as String,
        url: json['url'] as String,
        domain: json['domain'] as String?,
      );
}

/// A user tagged in a post. Kept intentionally thin (id + display fields) —
/// the private pet name for this person, if any, is resolved separately by
/// the viewer through `getDisplayName()` (connections feature), never
/// carried on the row itself.
class PostMentionedUser {
  const PostMentionedUser(
      {required this.profileId, this.fullName, this.avatarUrl});

  final String profileId;
  final String? fullName;
  final String? avatarUrl;

  factory PostMentionedUser.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return PostMentionedUser(
      profileId: json['mentioned_profile_id'] as String,
      fullName: profile?['full_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }
}

/// A Tech & Developer post (global feed — distinct from `community_posts`,
/// which is scoped to a single community).
class Post {
  const Post({
    required this.id,
    required this.authorId,
    this.authorName,
    this.authorAvatarUrl,
    this.authorHeadline,
    this.content,
    this.category,
    this.likeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.media = const [],
    this.links = const [],
    this.mentions = const [],
  });

  final String id;
  final String authorId;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? authorHeadline;
  final String? content;
  final String? category;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final List<PostMedia> media;
  final List<PostLink> links;
  final List<PostMentionedUser> mentions;

  factory Post.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    final media = (json['post_media'] as List<dynamic>?)
            ?.map((e) => PostMedia.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <PostMedia>[];
    final sortedMedia = [...media]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Post(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      authorName: author?['full_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      authorHeadline: author?['current_role'] as String?,
      content: json['content'] as String?,
      category: json['category'] as String?,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      media: sortedMedia,
      links: (json['post_links'] as List<dynamic>?)
              ?.map((e) => PostLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      mentions: (json['post_mentions'] as List<dynamic>?)
              ?.map(
                  (e) => PostMentionedUser.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// A comment on a post (`post_comments`) — mirrors `community_comments`.
class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.authorId,
    this.authorName,
    this.authorAvatarUrl,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String? authorName;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;

  factory PostComment.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return PostComment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorId: json['author_id'] as String,
      authorName: author?['full_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Known dev-topic categories — used for the composer's chip-select and the
/// feed's filter chips. Deliberately a fixed Dart list, not a DB enum: the
/// `category` column is plain text, so this list can change without a
/// migration (spec: keep the feed tech/developer-focused, not generic).
const kPostCategories = <String>[
  'Programming',
  'Web Development',
  'Mobile Development',
  'AI/ML',
  'Cloud',
  'DevOps',
  'Cybersecurity',
  'Open Source',
  'GitHub',
  'Startups',
  'Developer Tools',
  'Tech News',
  'Research',
  'Hackathons',
  'Projects',
  'Developer Experience',
];
