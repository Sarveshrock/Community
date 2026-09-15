/// A curated tech-intelligence feed item, produced entirely by the get-news
/// pipeline (fetch -> dedupe -> filter -> categorize -> rank -> store) —
/// never inserted by hand. Read straight from `news_items`.
class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.url,
    this.description,
    this.imageUrl,
    this.publishedAt,
    this.source,
    this.sourceType,
    this.category,
    this.tags = const [],
    this.isTrending = false,
    this.isFeatured = false,
  });

  final String id;
  final String title;
  final String url;
  final String? description;
  final String? imageUrl;
  final DateTime? publishedAt;
  final String? source;
  final String? sourceType;
  final String? category;
  final List<String> tags;
  final bool isTrending;
  final bool isFeatured;

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        id: json['id'] as String,
        title: json['title'] as String,
        url: json['url'] as String,
        description: json['description'] as String?,
        imageUrl: json['image_url'] as String?,
        publishedAt: json['published_at'] != null
            ? DateTime.tryParse(json['published_at'] as String)
            : null,
        source: json['source'] as String?,
        sourceType: json['source_type'] as String?,
        category: json['category'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
        isTrending: json['is_trending'] as bool? ?? false,
        isFeatured: json['is_featured'] as bool? ?? false,
      );
}

/// Mirrors section 6 of the tech-intelligence spec — used to drive the
/// category filter chips. "Other Tech" is the fallback the pipeline assigns
/// when nothing more specific matched.
const kNewsCategories = <String>[
  'AI',
  'Machine Learning',
  'LLM',
  'Research',
  'GitHub',
  'Open Source',
  'Startups',
  'Programming',
  'Web Development',
  'Mobile Development',
  'Cloud',
  'DevOps',
  'Cybersecurity',
  'Databases',
  'Backend',
  'Frontend',
  'Developer Tools',
  'Frameworks',
  'Programming Languages',
  'Robotics',
  'Blockchain/Web3',
  'Hardware',
  'Operating Systems',
  'Infrastructure',
  'Other Tech',
];
