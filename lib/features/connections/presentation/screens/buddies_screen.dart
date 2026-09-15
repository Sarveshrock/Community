import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../messaging/presentation/utils/open_direct_conversation.dart';
import '../../domain/entities/connection.dart';
import '../providers/connection_providers.dart';
import '../providers/buddy_category_provider.dart';

/// "Buddies": a personalized view of every accepted connection, each
/// labeled with the viewer's own private pet name where one has been set.
/// Deliberately built on top of the existing `connections`/`Connection`
/// stack rather than a parallel system — the only new capability here is
/// the pet name (`connection_nicknames`, migration 0029).
///
/// IMPORTANT PRODUCT NOTE: a later redesign brief for this screen described
/// a "Connect" discovery feed (find *new* people). That's a different
/// screen than what Buddies has always been (people you're *already*
/// connected with) — confirmed with the user to keep the existing scope.
/// So there is no "Connect" action here; the equivalent prominent CTA is
/// "Message", the natural primary action for an existing connection.
///
/// Visual language matches the redesigned Home/Discover pages (`HomeStyle` /
/// `GlowBackdrop` / `GradientBorderCard`) — this screen is a normal
/// `context.push`ed route sitting outside the bottom-nav shell, same as
/// People/Jobs/Hackathons/etc., so (deliberately) it has no bottom nav bar of
/// its own; adding one here without the shell driving it would either do
/// nothing when tapped or require new cross-shell navigation this redesign
/// wasn't asked to build.
class BuddiesScreen extends ConsumerStatefulWidget {
  const BuddiesScreen({super.key});

  @override
  ConsumerState<BuddiesScreen> createState() => _BuddiesScreenState();
}

class _BuddiesScreenState extends ConsumerState<BuddiesScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _query = '';
  BuddyCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<Connection> _filter(
    List<Connection> all,
    String myId,
    Map<String, BuddyCategory>? categoryMap,
  ) {
    return all.where((c) {
      if (_selectedCategory != null) {
        final category = categoryMap?[c.otherProfileId(myId)];
        if (category != _selectedCategory) return false;
      }
      if (_query.isEmpty) return true;
      final haystack = [
        c.otherProfileName ?? '',
        c.petName ?? '',
        c.otherProfileHeadline ?? '',
        c.otherProfileLocation ?? '',
        c.otherProfileBio ?? '',
        ...c.otherProfileInterests,
      ].join(' ').toLowerCase();
      return haystack.contains(_query);
    }).toList();
  }

  Future<void> _openCategorySheet() async {
    // showModalBottomSheet<T> returns null both when dismissed (tap outside
    // / back button) and when the sheet explicitly pops null — and "All" is
    // represented as null. So "All" pops the distinct [_allChoice] sentinel
    // instead, keeping "dismissed, leave selection alone" distinguishable
    // from "explicitly chose All".
    final result = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: HomeStyle.cardBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CategorySheet(selected: _selectedCategory),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedCategory =
          identical(result, _allChoice) ? null : result as BuddyCategory;
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final connectionsAsync = ref.watch(buddiesProvider);
    final categoryMapAsync = ref.watch(buddyCategoryMapProvider);

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: connectionsAsync.when(
                loading: () => Column(
                  children: [
                    _Header(
                      searchController: _searchController,
                      searchFocusNode: _searchFocusNode,
                      onFilterTap: _openCategorySheet,
                    ),
                    const Expanded(child: SkeletonList()),
                  ],
                ),
                error: (e, _) => Column(
                  children: [
                    _Header(
                      searchController: _searchController,
                      searchFocusNode: _searchFocusNode,
                      onFilterTap: _openCategorySheet,
                    ),
                    Expanded(
                      child: ErrorState(
                        message: e.toString(),
                        onRetry: () => ref.invalidate(buddiesProvider),
                      ),
                    ),
                  ],
                ),
                data: (connections) {
                  if (myId == null || connections.isEmpty) {
                    return Column(
                      children: [
                        _Header(
                          searchController: _searchController,
                          searchFocusNode: _searchFocusNode,
                          onFilterTap: _openCategorySheet,
                        ),
                        const Expanded(
                          child: EmptyState(
                            icon: Icons.favorite_border,
                            title: 'No connections yet',
                            message:
                                'People you connect with will show up here — give them a pet name to personalize the list.',
                          ),
                        ),
                      ],
                    );
                  }

                  final categoryMap = categoryMapAsync.valueOrNull;
                  final waitingOnCategories =
                      _selectedCategory != null && categoryMap == null;
                  final visible = waitingOnCategories
                      ? const <Connection>[]
                      : _filter(connections, myId, categoryMap);

                  return RefreshIndicator(
                    backgroundColor: HomeStyle.cardBase,
                    color: HomeStyle.purple,
                    onRefresh: () async {
                      ref.invalidate(buddiesProvider);
                      ref.invalidate(buddyCategoryMapProvider);
                    },
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _Header(
                            searchController: _searchController,
                            searchFocusNode: _searchFocusNode,
                            onFilterTap: _openCategorySheet,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _CategoryPills(
                            selected: _selectedCategory,
                            onSelected: (category) =>
                                setState(() => _selectedCategory = category),
                          ),
                        ),
                        if (waitingOnCategories)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: HomeStyle.purple),
                            ),
                          )
                        else if (visible.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(
                              icon: Icons.search_off,
                              title: 'No buddies found',
                              message: _selectedCategory == null
                                  ? 'Try a different search.'
                                  : 'Try changing your filters or search.',
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            sliver: SliverList.separated(
                              itemCount: visible.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) => _BuddyCard(
                                  connection: visible[i], myId: myId),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Distinct sentinel for "explicitly chose All" — see [_openCategorySheet].
const _allChoice = Object();

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({required this.selected});

  final BuddyCategory? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter by purpose',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: HomeStyle.textPrimary)),
            const SizedBox(height: 12),
            _SheetOption(
              icon: Icons.groups_rounded,
              label: 'All',
              selected: selected == null,
              onTap: () => Navigator.of(context).pop(_allChoice),
            ),
            for (final category in BuddyCategory.values)
              _SheetOption(
                icon: _iconFor(category),
                label: category.label,
                selected: selected == category,
                onTap: () => Navigator.of(context).pop(category),
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon,
          color: selected ? HomeStyle.purple : HomeStyle.textSecondary),
      title: Text(label,
          style: TextStyle(
            color: HomeStyle.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          )),
      trailing: selected
          ? const Icon(Icons.check_circle, color: HomeStyle.purple, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

IconData _iconFor(BuddyCategory category) {
  return switch (category) {
    BuddyCategory.friends => Icons.people_outline_rounded,
    BuddyCategory.mentors => Icons.school_outlined,
    BuddyCategory.mockInterview => Icons.record_voice_over_outlined,
    BuddyCategory.communities => Icons.groups_outlined,
    BuddyCategory.others => Icons.more_horiz_rounded,
  };
}

class _Header extends StatelessWidget {
  const _Header({
    required this.searchController,
    required this.searchFocusNode,
    required this.onFilterTap,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onTap: () => context.pop(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Buddies',
                      style: TextStyle(
                        fontSize: MediaQuery.sizeOf(context).width < 360
                            ? 22
                            : 25,
                        fontWeight: FontWeight.w800,
                        color: HomeStyle.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Find like-minded people for anything',
                      // Wraps instead of ellipsising: narrow phones (~360px
                      // and below, with two 44px icon buttons taking real
                      // width) don't fit this on one line without losing
                      // words, and a two-line subtitle costs nothing here.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.25,
                        color: HomeStyle.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _IconButton(
                icon: Icons.search_rounded,
                tooltip: 'Search',
                onTap: () => searchFocusNode.requestFocus(),
              ),
              const SizedBox(width: 8),
              _IconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Filter by purpose',
                highlighted: true,
                onTap: onFilterTap,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SearchField(
              controller: searchController, focusNode: searchFocusNode),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: highlighted
              ? HomeStyle.purple.withValues(alpha: 0.16)
              : HomeStyle.cardBase,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: BorderSide(
              color: highlighted
                  ? HomeStyle.purple.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon,
                  size: 21,
                  color:
                      highlighted ? HomeStyle.purple : HomeStyle.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() => _focused = widget.focusNode.hasFocus);

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
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
        boxShadow: _focused ? HomeStyle.glow(HomeStyle.purple, opacity: 0.18) : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        style: const TextStyle(color: HomeStyle.textPrimary, fontSize: 14.5),
        decoration: InputDecoration(
          hintText: 'Search buddies...',
          hintStyle: const TextStyle(color: HomeStyle.textSecondary),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 20, color: HomeStyle.textSecondary),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: HomeStyle.textSecondary),
                  onPressed: widget.controller.clear,
                  tooltip: 'Clear search',
                ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _CategoryPills extends StatelessWidget {
  const _CategoryPills({required this.selected, required this.onSelected});

  final BuddyCategory? selected;
  final ValueChanged<BuddyCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Pill(
            label: 'All',
            icon: Icons.groups_rounded,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final category in BuddyCategory.values) ...[
            const SizedBox(width: 8),
            _Pill(
              label: category.label,
              icon: _iconFor(category),
              selected: selected == category,
              onTap: () => onSelected(category),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label filter',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: selected ? HomeStyle.brandGradient : null,
              color: selected ? null : HomeStyle.cardBase,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: selected
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 16,
                      color:
                          selected ? Colors.white : HomeStyle.textSecondary),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFFD7DEF0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Deterministic per-user accent so avatar rings/borders vary card to card
/// (purely decorative) without depending on any "favorite color" field that
/// doesn't exist — same id always gets the same accent.
Color _accentFor(String id) {
  const accents = [
    HomeStyle.blue,
    HomeStyle.purple,
    HomeStyle.cyan,
    HomeStyle.pink,
    HomeStyle.green,
  ];
  return accents[id.hashCode.abs() % accents.length];
}

class _BuddyCard extends ConsumerStatefulWidget {
  const _BuddyCard({required this.connection, required this.myId});

  final Connection connection;
  final String myId;

  @override
  ConsumerState<_BuddyCard> createState() => _BuddyCardState();
}

class _BuddyCardState extends ConsumerState<_BuddyCard> {
  bool _busy = false;

  String get _otherId => widget.connection.otherProfileId(widget.myId);

  void _openProfile() => context.push(RoutePaths.personDetailOf(_otherId));

  Future<void> _message() => openDirectConversation(context, ref, _otherId);

  Future<void> _editPetName() async {
    final controller =
        TextEditingController(text: widget.connection.petName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.connection.petName == null
            ? 'Add a pet name'
            : 'Edit pet name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(
            hintText: widget.connection.otherProfileName ?? 'Nickname',
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          if (widget.connection.petName != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child:
                  Text('Remove', style: TextStyle(color: context.colors.error)),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    final notifier = ref.read(connectionControllerProvider.notifier);
    final trimmed = result.trim();
    final ok = trimmed.isEmpty
        ? await notifier.removePetName(widget.connection.id)
        : await notifier.setPetName(widget.connection.id, trimmed);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) context.showSnack('Could not save pet name', isError: true);
  }

  Future<void> _disconnect() async {
    final name = widget.connection.otherProfileName ?? 'this person';
    final confirmed = await showConfirmDialog(
      context,
      title: 'Disconnect?',
      message: 'Are you sure you want to disconnect from $name?',
      confirmLabel: 'Disconnect',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final ok = await ref
        .read(connectionControllerProvider.notifier)
        .disconnect(widget.connection.id);
    if (!mounted) return;
    setState(() => _busy = false);
    context.showSnack(ok ? 'Disconnected from $name' : 'Could not disconnect',
        isError: !ok);
  }

  @override
  Widget build(BuildContext context) {
    final connection = widget.connection;
    final accent = _accentFor(_otherId);
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final presence =
        BuddyPresence.fromUpdatedAt(connection.otherProfileUpdatedAt);

    return GradientBorderCard(
      radius: 22,
      borderWidth: 1,
      gradient: LinearGradient(
        colors: [
          accent.withValues(alpha: 0.28),
          HomeStyle.purple.withValues(alpha: 0.10),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      onTap: _busy ? null : _openProfile,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.3)]),
                    boxShadow: HomeStyle.glow(accent, opacity: 0.3, blur: 10),
                  ),
                  child: UserAvatar(
                    avatarUrl: connection.otherProfileAvatar,
                    name: connection.otherProfileName ?? '?',
                    radius: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              connection.displayName(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: HomeStyle.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _PresenceBadge(presence: presence),
                        ],
                      ),
                      if (connection.otherProfileHeadline != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.work_outline_rounded,
                                size: 13, color: HomeStyle.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                connection.otherProfileHeadline!,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: HomeStyle.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (connection.otherProfileLocation != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined,
                                size: 13, color: HomeStyle.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                connection.otherProfileLocation!,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: HomeStyle.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (connection.otherProfileInterests.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in connection.otherProfileInterests.take(4))
                    HomeChip(tag, accent: accent),
                ],
              ),
            ],
            if (connection.otherProfileBio != null &&
                connection.otherProfileBio!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                connection.otherProfileBio!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: Color(0xFFC3CBE3),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: narrow
                      ? Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _ActionButton(
                                      icon: Icons.person_outline_rounded,
                                      label: 'View Profile',
                                      onTap: _busy ? null : _openProfile),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _ActionButton(
                                      icon: Icons.edit_outlined,
                                      label: connection.petName == null
                                          ? 'Add Pet Name'
                                          : 'Edit Pet Name',
                                      onTap: _busy ? null : _editPetName),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _ActionButton(
                              icon: Icons.link_off_rounded,
                              label: 'Disconnect',
                              color: HomeStyle.pink,
                              onTap: _busy ? null : _disconnect,
                            ),
                          ],
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ActionButton(
                                icon: Icons.person_outline_rounded,
                                label: 'View Profile',
                                onTap: _busy ? null : _openProfile),
                            _ActionButton(
                                icon: Icons.edit_outlined,
                                label: connection.petName == null
                                    ? 'Add Pet Name'
                                    : 'Edit Pet Name',
                                onTap: _busy ? null : _editPetName),
                            _ActionButton(
                                icon: Icons.link_off_rounded,
                                label: 'Disconnect',
                                color: HomeStyle.pink,
                                onTap: _busy ? null : _disconnect),
                          ],
                        ),
                ),
                const SizedBox(width: 8),
                _MessageButton(
                  busy: _busy,
                  accent: accent,
                  onTap: _busy ? null : _message,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The card's prominent round CTA — occupies the visual slot the reference
/// gives to "Connect", but Message is the correct action here: everyone
/// shown on this screen is already an accepted connection.
class _MessageButton extends StatelessWidget {
  const _MessageButton({required this.busy, required this.accent, required this.onTap});

  final bool busy;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Message',
      child: Tooltip(
        message: 'Message',
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [accent, HomeStyle.purple]),
              boxShadow: HomeStyle.glow(accent, opacity: busy ? 0.15 : 0.35, blur: 12),
            ),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.chat_bubble_rounded,
                    size: 19, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _PresenceBadge extends StatelessWidget {
  const _PresenceBadge({required this.presence});

  final BuddyPresence presence;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: presence.label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: presence.isOnline
                  ? const Color(0xFF22D98A)
                  : const Color(0xFF6B7280),
              boxShadow: presence.isOnline
                  ? [
                      BoxShadow(
                        color: const Color(0xFF22D98A).withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            presence.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: presence.isOnline
                  ? const Color(0xFF22D98A)
                  : HomeStyle.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? HomeStyle.textSecondary;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: (color ?? Colors.white)
            .withValues(alpha: color != null ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: tint),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: color ?? HomeStyle.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
