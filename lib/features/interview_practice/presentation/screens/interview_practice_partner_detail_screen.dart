import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/models/skill.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../moderation/presentation/widgets/report_action_button.dart';
import '../providers/interview_practice_providers.dart';

class InterviewPracticePartnerDetailScreen extends ConsumerWidget {
  const InterviewPracticePartnerDetailScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerAsync = ref.watch(interviewPracticePartnerProvider(profileId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice Partner'),
        actions: [
          ReportActionButton(
              targetType: ReportTargetType.interviewPracticeProfile,
              targetId: profileId),
        ],
      ),
      body: partnerAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (p) => ResponsiveCenter(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatar(avatarUrl: p.avatarUrl, name: p.fullName ?? '?', radius: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.fullName ?? 'Community member',
                              style: context.textStyles.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          if (p.currentRole != null)
                            Text(p.currentRole!,
                                style: context.textStyles.bodyMedium?.copyWith(
                                    color: context.colors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(p.targetRole)),
                    Chip(label: Text(p.experienceLevel.label)),
                    for (final t in p.topics) Chip(label: Text(t)),
                  ],
                ),
                if (p.availabilityNotes != null) ...[
                  const SizedBox(height: 16),
                  Text('Availability',
                      style: context.textStyles.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(p.availabilityNotes!),
                ],
                const SizedBox(height: 24),
                _RequestPracticeForm(partnerId: p.profileId, defaultRole: p.targetRole),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestPracticeForm extends ConsumerStatefulWidget {
  const _RequestPracticeForm({required this.partnerId, required this.defaultRole});

  final String partnerId;
  final String defaultRole;

  @override
  ConsumerState<_RequestPracticeForm> createState() => _RequestPracticeFormState();
}

class _RequestPracticeFormState extends ConsumerState<_RequestPracticeForm> {
  final _formKey = GlobalKey<FormState>();
  late final _roleController = TextEditingController(text: widget.defaultRole);
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _roleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(interviewPracticeControllerProvider.notifier).requestPractice(
          widget.partnerId,
          targetRole: _roleController.text.trim(),
          message: _messageController.text.trim().isEmpty
              ? null
              : _messageController.text.trim(),
        );
    if (!mounted) return;
    context.showSnack(
        success ? 'Practice request sent' : 'Could not send request — you may already have one open',
        isError: !success);
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(interviewPracticeControllerProvider).isLoading;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Request a practice session',
              style: context.textStyles.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _roleController,
            decoration: const InputDecoration(labelText: 'Role to practice'),
            validator: (v) => Validators.required(v, fieldName: 'Target role'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _messageController,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Message (optional)', alignLabelWithHint: true),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.record_voice_over_outlined),
              label: const Text('Request practice'),
              onPressed: isSaving ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}
