import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/offline_banner.dart';
import '../widgets/home_style.dart';

/// Bottom navigation shell (spec section 58): Home / Discover / Create /
/// Messages / Profile. Each branch keeps its own navigation stack via
/// [StatefulShellRoute.indexedStack], so switching tabs preserves scroll
/// position instead of rebuilding from scratch.
///
/// The bar is hand-built rather than a Material [NavigationBar] because the
/// Create action sits raised above the bar — but it is still exactly five
/// destinations driving `navigationShell.goBranch`, so routing behaviour is
/// unchanged.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _createIndex = 2;

  void _go(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    final current = navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      // Deliberately NOT extendBody: the Scaffold reserves the bar's height
      // so page content can never scroll underneath it. Only the raised
      // Create button overhangs, and page padding keeps content clear of it.
      body: OfflineBanner(child: navigationShell),
      bottomNavigationBar: _CommuneoNavBar(
        currentIndex: current,
        onSelect: _go,
        createIndex: _createIndex,
      ),
    );
  }
}

class _CommuneoNavBar extends StatelessWidget {
  const _CommuneoNavBar({
    required this.currentIndex,
    required this.onSelect,
    required this.createIndex,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final int createIndex;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.explore_outlined, label: 'Discover'),
    (icon: Icons.add_rounded, label: 'Create'),
    (icon: Icons.chat_bubble_outline_rounded, label: 'Messages'),
    (icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      // The raised Create button overflows the bar's top edge.
      clipBehavior: Clip.none,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: i == createIndex
                          ? const SizedBox.shrink()
                          : _NavItem(
                              icon: _items[i].icon,
                              label: _items[i].label,
                              selected: currentIndex == i,
                              onTap: () => onSelect(i),
                            ),
                    ),
                ],
              ),
              Positioned(
                top: -20,
                left: 0,
                right: 0,
                child: Center(
                  child: _CreateButton(
                    selected: currentIndex == createIndex,
                    onTap: () => onSelect(createIndex),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
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
    final color = selected ? HomeStyle.purple : const Color(0xFFC3CBE3);

    return InkResponse(
      onTap: onTap,
      radius: 40,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            decoration: selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(colors: [
                      HomeStyle.blue.withValues(alpha: 0.35),
                      HomeStyle.purple.withValues(alpha: 0.45),
                    ]),
                  )
                : null,
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.1,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkResponse(
          onTap: onTap,
          radius: 34,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: HomeStyle.brandGradient,
              boxShadow: HomeStyle.glow(HomeStyle.purple,
                  opacity: selected ? 0.6 : 0.45, blur: 16),
            ),
            child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Create',
          style: TextStyle(
            fontSize: 10.5,
            height: 1.1,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? HomeStyle.purple : const Color(0xFFC3CBE3),
          ),
        ),
      ],
    );
  }
}
