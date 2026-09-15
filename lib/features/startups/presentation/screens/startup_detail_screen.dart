import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
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
      appBar: AppBar(
        title: const Text('Startup'),
        actions: [
          ReportActionButton(
              targetType: ReportTargetType.startup, targetId: startupId)
        ],
      ),
      body: startupAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (s) {
          final isOwner = s.ownerId == myId;
          return ResponsiveCenter(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(
                          avatarUrl: s.logoUrl, name: s.name, radius: 32),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: context.textStyles.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            Text(
                                [s.industry, s.stage]
                                    .whereType<String>()
                                    .join(' · '),
                                style: context.textStyles.bodyMedium?.copyWith(
                                    color: context.colors.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (s.description != null) Text(s.description!),
                  if (s.website != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.link),
                      label: Text(s.website!),
                      onPressed: () => launchUrl(Uri.parse(s.website!)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Open roles',
                          style: context.textStyles.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (isOwner)
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add role'),
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) =>
                                AddOpportunitySheet(startupId: startupId),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  opportunitiesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Could not load roles'),
                    data: (opportunities) {
                      if (opportunities.isEmpty) {
                        return const EmptyState(
                            icon: Icons.work_outline,
                            title: 'No open roles right now');
                      }
                      return Column(
                        children: [
                          for (final o in opportunities)
                            Card(
                              child: ListTile(
                                title: Text(o.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text([
                                  o.role,
                                  o.compensationType,
                                  o.isRemote ? 'Remote' : 'On-site'
                                ].whereType<String>().join(' · ')),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
