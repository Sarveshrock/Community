import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../connections/presentation/providers/connection_providers.dart';
import '../providers/search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: AppConstants.searchDebounceMs), () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search people, jobs, projects, hackathons, startups...',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
      ),
      body: ResponsiveCenter(
        child: query.isEmpty
            ? const EmptyState(
                icon: Icons.search, title: 'Search across the whole community')
            : resultsAsync.when(
                loading: () => const SkeletonList(),
                error: (e, _) => ErrorState(message: e.toString()),
                data: (results) {
                  if (results.isEmpty) {
                    return const EmptyState(
                        icon: Icons.search_off, title: 'No results found');
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (results.people.isNotEmpty)
                        ..._section(
                            context,
                            'People',
                            results.people,
                            (r) => getDisplayName(ref,
                                profileId: r['id'] as String,
                                mainName: r['full_name'] as String?),
                            (r) => r['current_role'] as String? ?? '',
                            (r) => context.push(
                                RoutePaths.personDetailOf(r['id'] as String))),
                      if (results.jobs.isNotEmpty)
                        ..._section(
                            context,
                            'Jobs',
                            results.jobs,
                            (r) => r['title'] as String? ?? '',
                            (r) => r['company_name'] as String? ?? '',
                            (r) => context.push(
                                RoutePaths.jobDetailOf(r['id'] as String))),
                      if (results.projects.isNotEmpty)
                        ..._section(
                            context,
                            'Projects',
                            results.projects,
                            (r) => r['title'] as String? ?? '',
                            (r) => r['category'] as String? ?? '',
                            (r) => context.push(
                                RoutePaths.projectDetailOf(r['id'] as String))),
                      if (results.hackathons.isNotEmpty)
                        ..._section(
                            context,
                            'Hackathons',
                            results.hackathons,
                            (r) => r['name'] as String? ?? '',
                            (r) => '',
                            (r) => context.push(RoutePaths.hackathonDetailOf(
                                r['id'] as String))),
                      if (results.startups.isNotEmpty)
                        ..._section(
                            context,
                            'Startups',
                            results.startups,
                            (r) => r['name'] as String? ?? '',
                            (r) => r['industry'] as String? ?? '',
                            (r) => context.push(
                                RoutePaths.startupDetailOf(r['id'] as String))),
                      if (results.mentors.isNotEmpty)
                        ..._section(
                            context,
                            'Mentors',
                            results.mentors,
                            (r) =>
                                (r['profiles'] as Map?)?['full_name']
                                    as String? ??
                                '',
                            (r) => r['bio'] as String? ?? '',
                            (r) => context.push(RoutePaths.mentorDetailOf(
                                r['profile_id'] as String))),
                      if (results.communities.isNotEmpty)
                        ..._section(
                            context,
                            'Communities',
                            results.communities,
                            (r) => r['name'] as String? ?? '',
                            (r) => r['description'] as String? ?? '',
                            (r) => context.push(RoutePaths.communityDetailOf(
                                r['id'] as String))),
                    ],
                  );
                },
              ),
      ),
    );
  }

  List<Widget> _section(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> items,
    String Function(Map<String, dynamic>) titleOf,
    String Function(Map<String, dynamic>) subtitleOf,
    void Function(Map<String, dynamic>) onTap,
  ) {
    return [
      Text(title,
          style: context.textStyles.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      for (final item in items)
        Card(
          child: ListTile(
            title: Text(titleOf(item)),
            subtitle:
                subtitleOf(item).isNotEmpty ? Text(subtitleOf(item)) : null,
            onTap: () => onTap(item),
          ),
        ),
      const SizedBox(height: 16),
    ];
  }
}
