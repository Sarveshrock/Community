import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/widgets/user_avatar.dart' show UserAvatar;
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/home_providers.dart';
import 'home_style.dart';

/// Communeo wordmark + tagline on the left, notifications and the signed-in
/// user's avatar on the right.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;

    return Row(
      children: [
        const _CommuneoMark(size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Communeo',
                style: TextStyle(
                  fontSize: 23,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: HomeStyle.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'PEOPLE  ×  PURPOSE  ×  PROGRESS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  height: 1.1,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                  color: HomeStyle.textSecondary.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _NotificationBell(unread: unread),
        const SizedBox(width: 12),
        _UserAvatar(
          name: profile?.displayName,
          avatarUrl: profile?.avatarUrl,
        ),
      ],
    );
  }
}

/// The Communeo mark: a small node-network glyph drawn with shapes rather
/// than a bitmap, so it stays crisp at any density and needs no asset.
class _CommuneoMark extends StatelessWidget {
  const _CommuneoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CommuneoMarkPainter()),
    );
  }
}

class _CommuneoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Node positions as fractions of the box.
    final hub = Offset(w * 0.42, h * 0.52);
    final nodes = <(Offset, double, Color)>[
      (Offset(w * 0.74, h * 0.20), w * 0.15, HomeStyle.blue),
      (Offset(w * 0.86, h * 0.56), w * 0.10, HomeStyle.cyan),
      (Offset(w * 0.60, h * 0.86), w * 0.11, HomeStyle.blue),
      (Offset(w * 0.16, h * 0.24), w * 0.10, HomeStyle.cyan),
      (Offset(w * 0.12, h * 0.72), w * 0.09, HomeStyle.blue),
    ];

    final link = Paint()
      ..color = HomeStyle.blue.withValues(alpha: 0.55)
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;
    for (final (pos, _, _) in nodes) {
      canvas.drawLine(hub, pos, link);
    }

    canvas.drawCircle(
        hub, w * 0.19, Paint()..color = const Color(0xFF2F6BFF));
    for (final (pos, r, color) in nodes) {
      canvas.drawCircle(pos, r, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () => context.push(RoutePaths.notifications),
      radius: 24,
      child: SizedBox(
        width: 30,
        height: 34,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_none_rounded,
                size: 26, color: HomeStyle.textPrimary),
            if (unread > 0)
              Positioned(
                top: 3,
                right: 2,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D6D),
                    shape: BoxShape.circle,
                    border: Border.all(color: HomeStyle.background, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({this.name, this.avatarUrl});

  final String? name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () => context.push(RoutePaths.profile),
      radius: 26,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: HomeStyle.brandGradient,
          boxShadow: HomeStyle.glow(HomeStyle.purple, opacity: 0.28, blur: 12),
        ),
        padding: const EdgeInsets.all(1.5),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF141A2E),
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          // Delegates to the shared UserAvatar rather than re-implementing
          // image/initials fallback here — the one previous exception to
          // "every avatar goes through UserAvatar", which is also what
          // recognizes a chosen illustrated avatar (generic_avatar.dart).
          child: UserAvatar(avatarUrl: avatarUrl, name: name ?? '?', radius: 20),
        ),
      ),
    );
  }
}
