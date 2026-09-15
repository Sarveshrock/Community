import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../providers/report_providers.dart';

export '../../domain/report_target.dart';

/// Reusable report flow (spec section 72) — reportable from profiles,
/// messages, jobs, projects, hackathons, communities, startups, and events.
/// Call this instead of hand-rolling another report menu item.
Future<void> showReportDialog(
  BuildContext context, {
  required ReportTargetType targetType,
  required String targetId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(targetType: targetType, targetId: targetId),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.targetType, required this.targetId});

  final ReportTargetType targetType;
  final String targetId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  ReportCategory _category = ReportCategory.spam;
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final success =
        await ref.read(reportControllerProvider.notifier).submitReport(
              targetType: widget.targetType,
              targetId: widget.targetId,
              category: _category,
              details: _detailsController.text.trim().isEmpty
                  ? null
                  : _detailsController.text.trim(),
            );
    if (!mounted) return;
    Navigator.of(context).pop();
    context.showSnack(
        success
            ? 'Report submitted. Thanks for keeping the community safe.'
            : 'Could not submit report',
        isError: !success);
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(reportControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report',
              style: context.textStyles.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Your report is confidential — your identity is never shared with the reported party.',
            style: context.textStyles.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in ReportCategory.values)
                ChoiceChip(
                  label: Text(category.label),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailsController,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Additional details (optional)'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isSubmitting ? null : _submit,
              style:
                  FilledButton.styleFrom(backgroundColor: context.colors.error),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit report'),
            ),
          ),
        ],
      ),
    );
  }
}
