import '../entities/search_results.dart';

abstract class SearchRepository {
  Future<SearchResults> search(String query);
}
