import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../connections/presentation/providers/connection_providers.dart';
import '../../../people/presentation/providers/people_providers.dart';
import '../providers/hackathon_providers.dart';

/// Lets a team requirement's creator search people and send a team
/// invitation (spec section 23) — the piece of team formation that was
/// previously wired at the data layer but never reachable from the UI.
class InviteToTeamSheet extends ConsumerStatefulWidget {
  const InviteToTeamSheet({super.key, required this.teamRequirementId});

  final String teamRequirementId;

  @override
  ConsumerState<InviteToTeamSheet> createState() => _InviteToTeamSheetState();
}

class _InviteToTeamSheetState extends ConsumerState<InviteToTeamSheet> {
  final _queryController = TextEditingController();
  Timer? _debounce;
  final Set<String> _invitedIds = {};

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: AppConstants.searchDebounceMs), () {
      ref.read(peopleFiltersProvider.notifier).state =
          PeopleFilters(query: value.trim().isEmpty ? null : value.trim());
    });
  }

  Future<void> _invite(String receiverId) async {
    final success =
        await ref.read(hackathonControllerProvider.notifier).sendInvitation(
              teamRequirementId: widget.teamRequirementId,
              receiverId: receiverId,
            );
    if (!mounted) return;
    if (success) {
      setState(() => _invitedIds.add(receiverId));
      context.showSnack('Invitation sent');
    } else {
      context.showSnack('Could not send invitation', isError: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    // Reset filters so the People tab isn't left filtered by this search.
    Future.microtask(() =>
        ref.read(peopleFiltersProvider.notifier).state = const PeopleFilters());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(peopleSearchResultsProvider);
    final isLoading = ref.watch(hackathonControllerProvider).isLoading;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invite to team',
                  style: context.textStyles.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: _queryController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by name, role, or company',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _onQueryChanged,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: resultsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(e.toString())),
                  data: (people) {
                    if (people.isEmpty) {
                      return const EmptyState(
                          icon: Icons.person_search_outlined,
                          title: 'No one found');
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: people.length,
                      itemBuilder: (context, i) {
                        final p = people[i];
                        final alreadyInvited = _invitedIds.contains(p.id);
                        return ListTile(
                          leading: UserAvatar(
                              avatarUrl: p.avatarUrl,
                              name: p.displayName,
                              radius: 20),
                          title: Text(getDisplayName(ref,
                              profileId: p.id, mainName: p.displayName)),
                          subtitle: Text(p.headline),
                          trailing: alreadyInvited
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : TextButton(
                                  onPressed:
                                      isLoading ? null : () => _invite(p.id),
                                  child: const Text('Invite'),
                                ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
