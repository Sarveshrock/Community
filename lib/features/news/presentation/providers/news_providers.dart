import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_events.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/network/supabase_config.dart';
import '../../data/repositories/news_repository_impl.dart';
import '../../domain/entities/news_comment.dart';
import '../../domain/entities/news_item.dart';
import '../../domain/repositories/news_repository.dart';

export '../../domain/entities/news_comment.dart';
export '../../domain/entities/news_item.dart';

final newsRepositoryProvider =
    Provider<NewsRepository>((ref) => NewsRepositoryImpl(supabase));

/// null = "Latest" (unfiltered). Mutually exclusive with the trending
/// toggle in the UI, though the repository call itself allows combining
/// them if a future screen wants that.
final newsCategoryFilterProvider = StateProvider<String?>((ref) => null);
final newsTrendingOnlyProvider = StateProvider<bool>((ref) => false);

const _pageSize = 20;

/// Paginated feed (spec section 19): starts at page 1 on build/filter
/// change, [loadMore] appends the next page. Filtering/ranking already
/// happened server-side in the pipeline — this only asks for the next
/// slice, never fetches everything and filters client-side.
class NewsFeedController extends AsyncNotifier<List<NewsItem>> {
  int _page = 1;
  bool _hasMore = true;

  bool get hasMore => _hasMore;

  @override
  Future<List<NewsItem>> build() async {
    ref.watch(newsCategoryFilterProvider);
    ref.watch(newsTrendingOnlyProvider);
    _page = 1;
    _hasMore = true;
    final first = await _fetchPage(1);
    if (first.length < _pageSize) _hasMore = false;
    return first;
  }

  Future<List<NewsItem>> _fetchPage(int page) {
    return ref.read(newsRepositoryProvider).listNews(
          category: ref.read(newsCategoryFilterProvider),
          trendingOnly: ref.read(newsTrendingOnlyProvider),
          page: page,
          pageSize: _pageSize,
        );
  }

  Future<void> loadMore() async {
    if (!_hasMore || state.isLoading) return;
    final current = state.valueOrNull ?? [];
    final next = await _fetchPage(_page + 1);
    _page += 1;
    if (next.length < _pageSize) _hasMore = false;
    state = AsyncData([...current, ...next]);
  }
}

final newsFeedControllerProvider =
    AsyncNotifierProvider<NewsFeedController, List<NewsItem>>(
        NewsFeedController.new);

final savedNewsProvider = FutureProvider<List<NewsItem>>((ref) {
  return ref.watch(newsRepositoryProvider).listSaved();
});

final isNewsSavedProvider =
    FutureProvider.family<bool, String>((ref, url) async {
  final saved = await ref.watch(savedNewsProvider.future);
  return saved.any((n) => n.url == url);
});

/// Every opinion/reply on one article, oldest first — keyed by the article's
/// URL rather than a `news_items.id` (see `0040_news_comments.sql` for why).
final newsCommentsProvider =
    FutureProvider.family<List<NewsComment>, String>((ref, articleUrl) {
  return ref.watch(newsRepositoryProvider).listComments(articleUrl);
});

class NewsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> save(NewsItem item) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(newsRepositoryProvider).saveNews(item));
    state = result;
    if (!result.hasError) {
      ref.invalidate(savedNewsProvider);
      ref.invalidate(isNewsSavedProvider(item.url));
    }
    return !result.hasError;
  }

  Future<bool> unsave(String url) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(newsRepositoryProvider).unsaveNews(url));
    state = result;
    if (!result.hasError) {
      ref.invalidate(savedNewsProvider);
      ref.invalidate(isNewsSavedProvider(url));
    }
    return !result.hasError;
  }

  Future<bool> hide(String url) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(newsRepositoryProvider).hideNews(url));
    state = result;
    if (!result.hasError) ref.invalidate(newsFeedControllerProvider);
    return !result.hasError;
  }

  void openArticle(String url) {
    ref
        .read(analyticsServiceProvider)
        .log(AnalyticsEvents.newsOpened, {'article_url': url});
  }

  Future<NewsComment?> addComment(
    String articleUrl,
    String content, {
    String? parentCommentId,
    String? mentionedProfileId,
  }) async {
    try {
      final comment = await ref.read(newsRepositoryProvider).addComment(
            articleUrl,
            content,
            parentCommentId: parentCommentId,
            mentionedProfileId: mentionedProfileId,
          );
      ref.invalidate(newsCommentsProvider(articleUrl));
      return comment;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteComment(String commentId, String articleUrl) async {
    try {
      await ref.read(newsRepositoryProvider).deleteComment(commentId);
      ref.invalidate(newsCommentsProvider(articleUrl));
      return true;
    } catch (_) {
      return false;
    }
  }
}

final newsControllerProvider =
    AsyncNotifierProvider<NewsController, void>(NewsController.new);
