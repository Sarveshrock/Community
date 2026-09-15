// Locks down the wire contract with the news_items table row shape
// (supabase/migrations/0025_tech_intelligence_pipeline.sql) — a mismatch
// here means the News tab silently renders blank fields.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/news/domain/entities/news_item.dart';

void main() {
  test('NewsItem.fromJson maps a fully populated row', () {
    final item = NewsItem.fromJson({
      'id': 'a1b2c3',
      'url': 'https://example.com/article',
      'title': 'Flutter 4 released',
      'description': 'A new major version ships.',
      'image_url': 'https://example.com/image.jpg',
      'published_at': '2026-09-01T12:00:00Z',
      'source': 'Example News',
      'source_type': 'news',
      'category': 'Frameworks',
      'tags': ['Frameworks', 'Mobile Development'],
      'is_trending': true,
      'is_featured': false,
    });

    expect(item.id, 'a1b2c3');
    expect(item.url, 'https://example.com/article');
    expect(item.title, 'Flutter 4 released');
    expect(item.description, 'A new major version ships.');
    expect(item.imageUrl, 'https://example.com/image.jpg');
    expect(item.publishedAt, DateTime.parse('2026-09-01T12:00:00Z'));
    expect(item.source, 'Example News');
    expect(item.sourceType, 'news');
    expect(item.category, 'Frameworks');
    expect(item.tags, ['Frameworks', 'Mobile Development']);
    expect(item.isTrending, true);
    expect(item.isFeatured, false);
  });

  test('NewsItem.fromJson tolerates missing optional fields', () {
    final item = NewsItem.fromJson({
      'id': 'x9y8z7',
      'url': 'https://example.com/minimal',
      'title': 'Minimal article',
    });

    expect(item.description, isNull);
    expect(item.imageUrl, isNull);
    expect(item.publishedAt, isNull);
    expect(item.source, isNull);
    expect(item.category, isNull);
    expect(item.tags, isEmpty);
    expect(item.isTrending, false);
    expect(item.isFeatured, false);
  });

  test('kNewsCategories has no duplicates and includes the core spec set', () {
    expect(kNewsCategories.toSet().length, kNewsCategories.length);
    for (final expected in [
      'AI',
      'GitHub',
      'Research',
      'Startups',
      'Open Source',
      'Cybersecurity'
    ]) {
      expect(kNewsCategories, contains(expected));
    }
  });
}
