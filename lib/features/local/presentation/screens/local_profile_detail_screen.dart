import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../messaging/presentation/utils/open_direct_conversation.dart';
import '../../domain/entities/local_entities.dart';
import '../providers/local_providers.dart';

/// Local candidate detail (spec section 63). Only ever shows what the
/// privacy-safe `get_local_candidates()` function already exposed — no
/// direct query for another user's exact profile ever happens here.
class LocalProfileDetailScreen extends ConsumerWidget {
  const LocalProfileDetailScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(localCandidatesProvider).valueOrNull ??
        const <LocalCandidate>[];
    final connectionAsync = ref.watch(localConnectionWithProvider(profileId));
    final isLoading = ref.watch(localControllerProvider).isLoading;

    LocalCandidate? candidate;
    for (final c in candidates) {
      if (c.profileId == profileId) {
        candidate = c;
        break;
      }
    }

    final connection = connectionAsync.valueOrNull;
    final displayName =
        candidate?.displayName ?? connection?.otherName ?? 'Someone nearby';
    final avatarUrl = candidate?.avatarUrl ?? connection?.otherAvatarUrl;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  const _Header(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [
                                  AppColors.localAccent,
                                  AppColors.localAccent.withValues(alpha: 0.4),
                                ]),
                                boxShadow: HomeStyle.glow(
                                    AppColors.localAccent,
                                    opacity: 0.3,
                                    blur: 16),
                              ),
                              child: UserAvatar(
                                  avatarUrl: avatarUrl,
                                  name: displayName,
                                  radius: 48),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Center(
                              child: Text(displayName,
                                  style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: HomeStyle.textPrimary))),
                          if (candidate != null) ...[
                            const SizedBox(height: 6),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.near_me,
                                      size: 14, color: AppColors.localAccent),
                                  const SizedBox(width: 4),
                                  Text(candidate.distanceBucket,
                                      style: const TextStyle(
                                          color: AppColors.localAccent,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          if (candidate?.bio != null &&
                              candidate!.bio!.isNotEmpty) ...[
                            const Text('About',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: HomeStyle.textPrimary)),
                            const SizedBox(height: 6),
                            Text(candidate.bio!,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.5,
                                    color: HomeStyle.textSecondary)),
                            const SizedBox(height: 24),
                          ],
                          connectionAsync.when(
                            loading: () => const LoadingState(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (connection) {
                              if (connection == null) {
                                return _SolidButton(
                                  icon: Icons.favorite_border,
                                  label: 'Send local connection request',
                                  onTap: isLoading
                                      ? null
                                      : () => ref
                                          .read(localControllerProvider
                                              .notifier)
                                          .sendRequest(profileId),
                                );
                              }
                              switch (connection.status) {
                                case LocalConnectionStatus.pending:
                                  return const _SolidButton(
                                      label: 'Request pending', onTap: null);
                                case LocalConnectionStatus.accepted:
                                  return Column(
                                    children: [
                                      _SolidButton(
                                        icon: Icons.chat_bubble_outline,
                                        label: 'Chat',
                                        onTap: () => openDirectConversation(
                                            context, ref, profileId),
                                      ),
                                      const SizedBox(height: 10),
                                      _OutlineButton(
                                        icon: Icons.event_available_outlined,
                                        label: 'Suggest a meetup',
                                        onTap: () => context.push(
                                            RoutePaths.meetupOf(connection.id)),
                                      ),
                                    ],
                                  );
                                default:
                                  return _SolidButton(
                                    icon: Icons.favorite_border,
                                    label: 'Send local connection request',
                                    onTap: isLoading
                                        ? null
                                        : () => ref
                                            .read(localControllerProvider
                                                .notifier)
                                            .sendRequest(profileId),
                                  );
                              }
                            },
                          ),
                        ],
                      ),
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
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _IconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onTap: () => context.pop()),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Local Profile',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary)),
          ),
        ],
      ),
    );
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

class _SolidButton extends StatelessWidget {
  const _SolidButton({this.icon, required this.label, required this.onTap});

  final IconData? icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onTap == null ? HomeStyle.cardBase : AppColors.localAccent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 18,
                    color:
                        onTap == null ? HomeStyle.textSecondary : Colors.white),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: TextStyle(
                      color:
                          onTap == null ? HomeStyle.textSecondary : Colors.white,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({this.icon, required this.label, required this.onTap});

  final IconData? icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.localAccent.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppColors.localAccent),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: const TextStyle(
                      color: AppColors.localAccent, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
