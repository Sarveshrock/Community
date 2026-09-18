import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../home/presentation/widgets/home_style.dart';
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
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  const _Header(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
                      backgroundColor: HomeStyle.cardBase,
                      color: HomeStyle.purple,
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
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: reports.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final r = reports[i];
                              return Material(
                                color: HomeStyle.cardBase,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _showActionSheet(context, r),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.06)),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  '${r.category.label} · ${r.targetType.name}',
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: HomeStyle
                                                          .textPrimary)),
                                              const SizedBox(height: 4),
                                              if (r.details != null &&
                                                  r.details!.isNotEmpty) ...[
                                                Text(r.details!,
                                                    style: const TextStyle(
                                                        fontSize: 12.5,
                                                        color: HomeStyle
                                                            .textSecondary)),
                                                const SizedBox(height: 2),
                                              ],
                                              Text(
                                                  'Reported by ${r.reporterName ?? 'unknown'} · ${timeago.format(r.createdAt)}',
                                                  style: const TextStyle(
                                                      fontSize: 11.5,
                                                      color: HomeStyle
                                                          .textSecondary)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        HomeChip(r.status.label,
                                            accent: HomeStyle.blue),
                                      ],
                                    ),
                                  ),
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
          ),
        ],
      ),
    );
  }

  Widget _filterChip(ReportStatus? status, String label) {
    final selected = _filter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: () => setState(() => _filter = status),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: selected ? HomeStyle.brandGradient : null,
              color: selected ? null : HomeStyle.cardBase,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.10)),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : HomeStyle.textSecondary)),
          ),
        ),
      ),
    );
  }

  Future<void> _showActionSheet(BuildContext context, Report report) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HomeStyle.cardBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _ActionOption(
              icon: Icons.visibility_outlined,
              label: 'Mark reviewing',
              onTap: () => Navigator.pop(context, 'reviewing'),
            ),
            _ActionOption(
              icon: Icons.check_circle_outline,
              label: 'Resolve (action taken)',
              onTap: () => Navigator.pop(context, 'resolved'),
            ),
            _ActionOption(
              icon: Icons.block_outlined,
              label: 'Dismiss (no action)',
              onTap: () => Navigator.pop(context, 'dismissed'),
            ),
            const SizedBox(height: 8),
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
            child: Text('Moderation queue',
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

class _ActionOption extends StatelessWidget {
  const _ActionOption({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: HomeStyle.purple),
      title: Text(label, style: const TextStyle(color: HomeStyle.textPrimary)),
      onTap: onTap,
    );
  }
}
