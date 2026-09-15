import '../entities/news_comment.dart';
import '../entities/news_item.dart';

abstract class NewsRepository {
  /// Reads the already-curated feed straight from `news_items` — filtering
  /// and ranking happened server-side in the pipeline, never here (spec:
  /// "do not fetch hundreds of irrelevant records into Flutter and filter
  /// them there"). [category] is one of [kNewsCategories], or null for the
  /// unfiltered "Latest" feed; [trendingOnly] selects `is_trending` items.
  Future<List<NewsItem>> listNews({
    String? category,
    bool trendingOnly = false,
    int page = 1,
    int pageSize = 20,
  });

  Future<void> saveNews(NewsItem item);
  Future<void> unsaveNews(String articleUrl);
  Future<void> hideNews(String articleUrl);
  Future<List<NewsItem>> listSaved();
  Future<Set<String>> listHiddenUrls();

  /// Every non-deleted opinion/reply on one article, oldest first.
  Future<List<NewsComment>> listComments(String articleUrl);

  /// [parentCommentId]/[mentionedProfileId] are both null for a top-level
  /// opinion; a reply sets both (see [NewsComment] for why they can differ).
  Future<NewsComment> addComment(
    String articleUrl,
    String content, {
    String? parentCommentId,
    String? mentionedProfileId,
  });

  Future<void> deleteComment(String commentId);
}
