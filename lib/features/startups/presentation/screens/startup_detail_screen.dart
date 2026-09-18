import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../moderation/presentation/widgets/report_action_button.dart';
import '../providers/startup_providers.dart';
import '../widgets/add_opportunity_sheet.dart';

class StartupDetailScreen extends ConsumerWidget {
  const StartupDetailScreen({super.key, required this.startupId});

  final String startupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startupAsync = ref.watch(startupDetailProvider(startupId));
    final opportunitiesAsync =
        ref.watch(startupOpportunitiesProvider(startupId));
    final myId = ref.watch(authStateProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  _Header(startupId: startupId),
                  Expanded(
                    child: startupAsync.when(
                      loading: () => const LoadingState(),
                      error: (e, _) => ErrorState(message: e.toString()),
                      data: (s) {
                        final isOwner = s.ownerId == myId;
                        return SingleChildScrollView(
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
                                      boxShadow: HomeStyle.glow(
                                          HomeStyle.purple,
                                          opacity: 0.3,
                                          blur: 12),
                                    ),
                                    child: UserAvatar(
                                        avatarUrl: s.logoUrl,
                                        name: s.name,
                                        radius: 32),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(s.name,
                                            style: const TextStyle(
                                                fontSize: 19,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    HomeStyle.textPrimary)),
                                        const SizedBox(height: 2),
                                        Text(
                                            [s.industry, s.stage]
                                                .whereType<String>()
                                                .join(' · '),
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color:
                                                    HomeStyle.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              if (s.description != null)
                                Text(s.description!,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        height: 1.5,
                                        color: HomeStyle.textPrimary)),
                              if (s.website != null) ...[
                                const SizedBox(height: 14),
                                _LinkChip(
                                  label: s.website!,
                                  onTap: () =>
                                      launchUrl(Uri.parse(s.website!)),
                                ),
                              ],
                              const SizedBox(height: 26),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Open roles',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: HomeStyle.textPrimary)),
                                  if (isOwner)
                                    _AddButton(
                                      onTap: () => showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: HomeStyle.cardBase,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(20)),
                                        ),
                                        builder: (_) => AddOpportunitySheet(
                                            startupId: startupId),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              opportunitiesAsync.when(
                                loading: () => const LinearProgressIndicator(
                                    color: HomeStyle.purple),
                                error: (_, __) => const Text(
                                    'Could not load roles',
                                    style: TextStyle(
                                        color: HomeStyle.textSecondary)),
                                data: (opportunities) {
                                  if (opportunities.isEmpty) {
                                    return const EmptyState(
                                        icon: Icons.work_outline,
                                        title: 'No open roles right now');
                                  }
                                  return Column(
                                    children: [
                                      for (final o in opportunities)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 10),
                                          child: Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: HomeStyle.cardBase,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                  color: Colors.white
                                                      .withValues(
                                                          alpha: 0.06)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(o.title,
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: HomeStyle
                                                            .textPrimary)),
                                                const SizedBox(height: 3),
                                                Text(
                                                    [
                                                      o.role,
                                                      o.compensationType,
                                                      o.isRemote
                                                          ? 'Remote'
                                                          : 'On-site'
                                                    ]
                                                        .whereType<String>()
                                                        .join(' · '),
                                                    style: const TextStyle(
                                                        fontSize: 12.5,
                                                        color: HomeStyle
                                                            .textSecondary)),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
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
}

class _Header extends StatelessWidget {
  const _Header({required this.startupId});

  final String startupId;

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
            child: Text('Startup',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary)),
          ),
          ReportActionButton(
              targetType: ReportTargetType.startup, targetId: startupId),
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

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeStyle.purple.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: HomeStyle.purple),
              SizedBox(width: 4),
              Text('Add role',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: HomeStyle.purple)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeStyle.purple.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link, size: 16, color: HomeStyle.purple),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: HomeStyle.purple,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
