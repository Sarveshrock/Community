import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_config.dart';
import '../../data/repositories/search_repository_impl.dart';
import '../../domain/entities/search_results.dart';
import '../../domain/repositories/search_repository.dart';

export '../../domain/entities/search_results.dart';

final searchRepositoryProvider =
    Provider<SearchRepository>((ref) => SearchRepositoryImpl(supabase));

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const SearchResults();
  return ref.watch(searchRepositoryProvider).search(query);
});
