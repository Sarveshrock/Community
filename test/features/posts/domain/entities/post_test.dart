// Locks down Post.fromJson's nested-relation parsing (author, post_media,
// post_links, post_mentions) — a mismatch here means media/links/tagged
// users silently go blank in the feed, same failure mode already covered
// for TeamRequirement.fromJson.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/posts/domain/entities/post.dart';

void main() {
  test('Post.fromJson parses author, media (sorted), links, and mentions', () {
    final post = Post.fromJson({
      'id': 'post-1',
      'author_id': 'author-1',
      'content': 'Shipped a new Flutter release 🚀',
      'category': 'Mobile Development',
      'like_count': 3,
      'comment_count': 1,
      'created_at': '2026-01-01T00:00:00Z',
      'author': {
        'full_name': 'Ada',
        'avatar_url': 'https://x.test/a.png',
        'current_role': 'Engineer'
      },
      'post_media': [
        {
          'id': 'm2',
          'media_type': 'image',
          'storage_path': 'author-1/two.png',
          'sort_order': 1
        },
        {
          'id': 'm1',
          'media_type': 'video',
          'storage_path': 'author-1/one.mp4',
          'sort_order': 0
        },
      ],
      'post_links': [
        {
          'id': 'l1',
          'url': 'https://github.com/foo/bar',
          'domain': 'github.com'
        },
      ],
      'post_mentions': [
        {
          'mentioned_profile_id': 'user-2',
          'profiles': {'full_name': 'Ben', 'avatar_url': null},
        },
      ],
    });

    expect(post.authorName, 'Ada');
    expect(post.content, 'Shipped a new Flutter release 🚀');
    expect(post.category, 'Mobile Development');
    expect(post.likeCount, 3);
    expect(post.commentCount, 1);

    // Sorted by sort_order despite arriving out of order.
    expect(post.media.map((m) => m.id).toList(), ['m1', 'm2']);
    expect(post.media.first.type, PostMediaType.video);
    expect(post.media.last.type, PostMediaType.image);

    expect(post.links, hasLength(1));
    expect(post.links.first.domain, 'github.com');

    expect(post.mentions, hasLength(1));
    expect(post.mentions.first.profileId, 'user-2');
    expect(post.mentions.first.fullName, 'Ben');
  });

  test('Post.fromJson tolerates missing nested relations (text-only post)', () {
    final post = Post.fromJson({
      'id': 'post-2',
      'author_id': 'author-1',
      'content': 'Just text, no media.',
      'created_at': '2026-01-01T00:00:00Z',
    });

    expect(post.media, isEmpty);
    expect(post.links, isEmpty);
    expect(post.mentions, isEmpty);
    expect(post.likeCount, 0);
    expect(post.commentCount, 0);
    expect(post.category, isNull);
  });

  test('kPostCategories has no duplicates', () {
    expect(kPostCategories.toSet().length, kPostCategories.length);
  });
}
