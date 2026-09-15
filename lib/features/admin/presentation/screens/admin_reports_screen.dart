import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../moderation/domain/report_target.dart';
import '../providers/admin_providers.dart';

/// Moderation queue for admins/moderators (spec sections 72-73). The screen
/// itself never decides who is authorized — it's only reachable from
/// Settings when [isAdminProvider] is true, and every mutation still goes
/// through RLS's `is_admin()` check server-side.
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  ReportStatus? _filter = ReportStatus.open;

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(reportsQueueProvider(_filter));

    return Scaffold(
      appBar: AppBar(title: const Text('Moderation queue')),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(null, 'All'),
                    for (final s in ReportStatus.values)
                      _filterChip(s, s.label),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(reportsQueueProvider(_filter)),
                child: reportsAsync.when(
                  loading: () => const SkeletonList(),
                  error: (e, _) => ErrorState(
                      message: e.toString(),
                      onRetry: () =>
                          ref.invalidate(reportsQueueProvider(_filter))),
                  data: (reports) {
                    if (reports.isEmpty) {
                      return const EmptyState(
                          icon: Icons.shield_outlined,
                          title: 'No reports here');
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: reports.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final r = reports[i];
                        return Card(
                          child: ListTile(
                            title: Text(
                                '${r.category.label} · ${r.targetType.name}'),
                            subtitle: Text(
                              [
                                if (r.details != null && r.details!.isNotEmpty)
                                  r.details!,
                                'Reported by ${r.reporterName ?? 'unknown'} · ${timeago.format(r.createdAt)}',
                              ].join('\n'),
                            ),
                            isThreeLine:
                                r.details != null && r.details!.isNotEmpty,
                            trailing: Chip(
                                label: Text(r.status.label),
                                visualDensity: VisualDensity.compact),
                            onTap: () => _showActionSheet(context, r),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(ReportStatus? status, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == status,
        onSelected: (_) => setState(() => _filter = status),
      ),
    );
  }

  Future<void> _showActionSheet(BuildContext context, Report report) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Mark reviewing'),
              onTap: () => Navigator.pop(context, 'reviewing'),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Resolve (action taken)'),
              onTap: () => Navigator.pop(context, 'resolved'),
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('Dismiss (no action)'),
              onTap: () => Navigator.pop(context, 'dismissed'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    final status = switch (action) {
      'reviewing' => ReportStatus.reviewing,
      'resolved' => ReportStatus.resolved,
      _ => ReportStatus.dismissed,
    };

    final ok = await ref.read(adminControllerProvider.notifier).resolveReport(
          report.id,
          status: status,
          targetType: report.targetType,
          targetId: report.targetId,
          action: action,
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok ? 'Report updated' : 'Could not update report')),
    );
  }
}
