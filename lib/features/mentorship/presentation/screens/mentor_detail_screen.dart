import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/mentor_providers.dart';

class MentorDetailScreen extends ConsumerWidget {
  const MentorDetailScreen({super.key, required this.mentorId});

  final String mentorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mentorAsync = ref.watch(mentorDetailProvider(mentorId));
    final isLoading = ref.watch(mentorControllerProvider).isLoading;

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
                    child: mentorAsync.when(
                      loading: () => const LoadingState(),
                      error: (e, _) => ErrorState(message: e.toString()),
                      data: (m) => SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: HomeStyle.brandGradient,
                                    boxShadow: HomeStyle.glow(HomeStyle.pink,
                                        opacity: 0.3, blur: 12),
                                  ),
                                  child: UserAvatar(
                                      avatarUrl: m.avatarUrl,
                                      name: m.fullName ?? '?',
                                      radius: 32),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(m.fullName ?? 'Mentor',
                                          style: const TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w800,
                                              color: HomeStyle.textPrimary)),
                                      if (m.currentRole != null) ...[
                                        const SizedBox(height: 2),
                                        Text(m.currentRole!,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color:
                                                    HomeStyle.textSecondary)),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            if (m.bio != null) ...[
                              Text(m.bio!,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      height: 1.5,
                                      color: HomeStyle.textPrimary)),
                              const SizedBox(height: 16),
                            ],
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                HomeChip(
                                    '${m.sessionDurationMinutes} min sessions',
                                    accent: HomeStyle.blue),
                                HomeChip(
                                    m.pricingType == 'free'
                                        ? 'Free'
                                        : '${m.price ?? ''} ${m.currency ?? ''}',
                                    accent: m.pricingType == 'free'
                                        ? HomeStyle.green
                                        : HomeStyle.amber),
                                for (final t in m.topics)
                                  HomeChip(t, accent: HomeStyle.purple),
                              ],
                            ),
                            const SizedBox(height: 26),
                            Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: isLoading
                                    ? null
                                    : () async {
                                        final success = await ref
                                            .read(mentorControllerProvider
                                                .notifier)
                                            .requestMentorship(mentorId);
                                        if (success && context.mounted) {
                                          context.showSnack('Request sent');
                                        }
                                      },
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: isLoading
                                        ? null
                                        : HomeStyle.brandGradient,
                                    color: isLoading
                                        ? HomeStyle.cardBase
                                        : null,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: HomeStyle.purple),
                                        )
                                      : const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.school_outlined,
                                                size: 18, color: Colors.white),
                                            SizedBox(width: 8),
                                            Text('Request mentorship',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
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
            child: Text('Mentor',
                style: TextStyle(
                    fontSize: 20,
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
