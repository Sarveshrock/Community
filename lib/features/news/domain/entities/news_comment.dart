/// One user's opinion on a news article (`news_comments`), or a reply to
/// another comment. Threading is flattened one level deep: [parentCommentId]
/// always points at a top-level comment, so a reply-to-a-reply still nests
/// directly under the original comment — [mentionedProfileId]/[mentionedName]
/// carry who that particular reply is actually addressed to (the "@Name"
/// tag), independent of which top-level thread it lives under.
class NewsComment {
  const NewsComment({
    required this.id,
    required this.articleUrl,
    required this.authorId,
    this.authorName,
    this.authorAvatarUrl,
    required this.content,
    required this.createdAt,
    this.parentCommentId,
    this.mentionedProfileId,
    this.mentionedName,
  });

  final String id;
  final String articleUrl;
  final String authorId;
  final String? authorName;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;
  final String? parentCommentId;
  final String? mentionedProfileId;
  final String? mentionedName;

  bool get isReply => parentCommentId != null;

  factory NewsComment.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    final mentioned = json['mentioned'] as Map<String, dynamic>?;
    return NewsComment(
      id: json['id'] as String,
      articleUrl: json['article_url'] as String,
      authorId: json['author_id'] as String,
      authorName: author?['full_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      parentCommentId: json['parent_comment_id'] as String?,
      mentionedProfileId: json['mentioned_profile_id'] as String?,
      mentionedName: mentioned?['full_name'] as String?,
    );
  }
}
