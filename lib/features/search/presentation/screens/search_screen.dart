import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../connections/presentation/providers/connection_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

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
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        _IconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Back',
                          onTap: () => context.pop(),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: HomeStyle.cardBase,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _focused
                                    ? HomeStyle.purple.withValues(alpha: 0.7)
                                    : Colors.white.withValues(alpha: 0.08),
                                width: _focused ? 1.4 : 1,
                              ),
                              boxShadow: _focused
                                  ? HomeStyle.glow(HomeStyle.purple,
                                      opacity: 0.18)
                                  : null,
                            ),
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              autofocus: true,
                              style: const TextStyle(
                                  color: HomeStyle.textPrimary, fontSize: 14.5),
                              decoration: InputDecoration(
                                hintText: 'Search people, jobs, projects...',
                                hintStyle: const TextStyle(
                                    color: HomeStyle.textSecondary),
                                prefixIcon: const Icon(Icons.search_rounded,
                                    size: 20, color: HomeStyle.textSecondary),
                                suffixIcon: _controller.text.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.close_rounded,
                                            size: 18,
                                            color: HomeStyle.textSecondary),
                                        onPressed: () {
                                          _controller.clear();
                                          _onChanged('');
                                        },
                                      ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onChanged: _onChanged,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: query.isEmpty
                        ? const EmptyState(
                            icon: Icons.search,
                            title: 'Search across the whole community',
                            message:
                                'People, jobs, projects, hackathons, startups, mentors and communities.')
                        : resultsAsync.when(
                            loading: () => const SkeletonList(),
                            error: (e, _) => ErrorState(message: e.toString()),
                            data: (results) {
                              if (results.isEmpty) {
                                return const EmptyState(
                                    icon: Icons.search_off,
                                    title: 'No results found');
                              }
                              return ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                children: [
                                  if (results.people.isNotEmpty)
                                    ..._section(
                                        context,
                                        'People',
                                        HomeStyle.blue,
                                        results.people,
                                        (r) => getDisplayName(ref,
                                            profileId: r['id'] as String,
                                            mainName:
                                                r['full_name'] as String?),
                                        (r) =>
                                            r['current_role'] as String? ?? '',
                                        (r) => context.push(
                                            RoutePaths.personDetailOf(
                                                r['id'] as String))),
                                  if (results.jobs.isNotEmpty)
                                    ..._section(
                                        context,
                                        'Jobs',
                                        HomeStyle.amber,
                                        results.jobs,
                                        (r) => r['title'] as String? ?? '',
                                        (r) =>
                                            r['company_name'] as String? ?? '',
                                        (r) => context.push(
                                            RoutePaths.jobDetailOf(
                                                r['id'] as String))),
                                  if (results.projects.isNotEmpty)
                                    ..._section(
                                        context,
                                        'Projects',
                                        HomeStyle.violet,
                                        results.projects,
                                        (r) => r['title'] as String? ?? '',
                                        (r) => r['category'] as String? ?? '',
                                        (r) => context.push(
                                            RoutePaths.projectDetailOf(
                                                r['id'] as String))),
                                  if (results.hackathons.isNotEmpty)
                                    ..._section(
                                        context,
                                        'Hackathons',
                                        HomeStyle.green,
                                        results.hackathons,
                                        (r) => r['name'] as String? ?? '',
                                        (r) => '',
                                        (r) => context.push(
                                            RoutePaths.hackathonDetailOf(
                                                r['id'] as String))),
                                  if (results.startups.isNotEmpty)
                                    ..._section(
                                        context,
                                        'Startups',
                                        HomeStyle.cyan,
                                        results.startups,
                                        (r) => r['name'] as String? ?? '',
                                        (r) => r['industry'] as String? ?? '',
                                        (r) => context.push(
                                            RoutePaths.startupDetailOf(
                                                r['id'] as String))),
                                  if (results.mentors.isNotEmpty)
                                    ..._section(
                                        context,
                                        'Mentors',
                                        HomeStyle.pink,
                                        results.mentors,
                                        (r) => (r['profiles']
                                                    as Map?)?['full_name']
                                                as String? ??
                                            '',
                                        (r) => r['bio'] as String? ?? '',
                                        (r) => context.push(
                                            RoutePaths.mentorDetailOf(
                                                r['profile_id'] as String))),
                                  if (results.communities.isNotEmpty)
                                    ..._section(
                                        context,
                                        'Communities',
                                        HomeStyle.purple,
                                        results.communities,
                                        (r) => r['name'] as String? ?? '',
                                        (r) =>
                                            r['description'] as String? ?? '',
                                        (r) => context.push(
                                            RoutePaths.communityDetailOf(
                                                r['id'] as String))),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _section(
    BuildContext context,
    String title,
    Color accent,
    List<Map<String, dynamic>> items,
    String Function(Map<String, dynamic>) titleOf,
    String Function(Map<String, dynamic>) subtitleOf,
    void Function(Map<String, dynamic>) onTap,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: HomeStyle.textPrimary)),
      ),
      for (final item in items) ...[
        Material(
          color: HomeStyle.cardBase,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onTap(item),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titleOf(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: HomeStyle.textPrimary)),
                        if (subtitleOf(item).isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(subtitleOf(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: HomeStyle.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: HomeStyle.textSecondary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 12),
    ];
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: HomeStyle.cardBase,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 21, color: HomeStyle.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
