import 'package:flutter/material.dart';

import 'report_dialog.dart';

export '../../domain/report_target.dart';

/// Single-purpose report affordance for content that isn't a person (jobs,
/// projects, hackathons, startups, communities, events — spec section 72).
/// For profiles/messages, which also support Block, use a PopupMenuButton
/// with `showReportDialog` directly instead.
class ReportActionButton extends StatelessWidget {
  const ReportActionButton(
      {super.key, required this.targetType, required this.targetId});

  final ReportTargetType targetType;
  final String targetId;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.flag_outlined),
      tooltip: 'Report',
      onPressed: () =>
          showReportDialog(context, targetType: targetType, targetId: targetId),
    );
  }
}
