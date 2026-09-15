// Locks down the wire contract with news_comments (0040_news_comments.sql),
// including the joined author/mentioned-profile shape the repository's
// select string produces.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/news/domain/entities/news_comment.dart';

void main() {
  test('NewsComment.fromJson maps a top-level opinion', () {
    final comment = NewsComment.fromJson({
      'id': 'c1',
      'article_url': 'https://example.com/article',
      'author_id': 'u1',
      'author': {'full_name': 'Ada Lovelace', 'avatar_url': 'https://a.png'},
      'content': 'Great write-up!',
      'created_at': '2026-09-01T12:00:00Z',
      'parent_comment_id': null,
      'mentioned_profile_id': null,
      'mentioned': null,
    });

    expect(comment.id, 'c1');
    expect(comment.articleUrl, 'https://example.com/article');
    expect(comment.authorId, 'u1');
    expect(comment.authorName, 'Ada Lovelace');
    expect(comment.authorAvatarUrl, 'https://a.png');
    expect(comment.content, 'Great write-up!');
    expect(comment.createdAt, DateTime.parse('2026-09-01T12:00:00Z'));
    expect(comment.isReply, isFalse);
    expect(comment.mentionedProfileId, isNull);
    expect(comment.mentionedName, isNull);
  });

  test('NewsComment.fromJson maps a reply, tagging who it is addressed to', () {
    final reply = NewsComment.fromJson({
      'id': 'c2',
      'article_url': 'https://example.com/article',
      'author_id': 'u2',
      'author': {'full_name': 'Grace Hopper'},
      'content': '@Ada Lovelace totally agree',
      'created_at': '2026-09-01T12:05:00Z',
      'parent_comment_id': 'c1',
      'mentioned_profile_id': 'u1',
      'mentioned': {'full_name': 'Ada Lovelace'},
    });

    expect(reply.isReply, isTrue);
    expect(reply.parentCommentId, 'c1');
    expect(reply.mentionedProfileId, 'u1');
    expect(reply.mentionedName, 'Ada Lovelace');
  });

  test('NewsComment.fromJson tolerates absent author/mentioned embeds', () {
    final comment = NewsComment.fromJson({
      'id': 'c3',
      'article_url': 'https://example.com/article',
      'author_id': 'u3',
      'content': 'No embed present',
      'created_at': '2026-09-01T12:10:00Z',
    });

    expect(comment.authorName, isNull);
    expect(comment.authorAvatarUrl, isNull);
    expect(comment.mentionedName, isNull);
    expect(comment.isReply, isFalse);
  });
}
