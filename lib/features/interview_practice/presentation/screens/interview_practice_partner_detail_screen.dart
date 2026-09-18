import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/models/skill.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../moderation/presentation/widgets/report_action_button.dart';
import '../providers/interview_practice_providers.dart';

class InterviewPracticePartnerDetailScreen extends ConsumerWidget {
  const InterviewPracticePartnerDetailScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerAsync = ref.watch(interviewPracticePartnerProvider(profileId));

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  _Header(profileId: profileId),
                  Expanded(
                    child: partnerAsync.when(
                      loading: () => const LoadingState(),
                      error: (e, _) => ErrorState(message: e.toString()),
                      data: (p) => SingleChildScrollView(
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
                                    boxShadow: HomeStyle.glow(HomeStyle.cyan,
                                        opacity: 0.3, blur: 12),
                                  ),
                                  child: UserAvatar(
                                      avatarUrl: p.avatarUrl,
                                      name: p.fullName ?? '?',
                                      radius: 32),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(p.fullName ?? 'Community member',
                                          style: const TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w800,
                                              color: HomeStyle.textPrimary)),
                                      if (p.currentRole != null) ...[
                                        const SizedBox(height: 2),
                                        Text(p.currentRole!,
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
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                HomeChip(p.targetRole, accent: HomeStyle.cyan),
                                HomeChip(p.experienceLevel.label,
                                    accent: HomeStyle.blue),
                                for (final t in p.topics)
                                  HomeChip(t, accent: HomeStyle.purple),
                              ],
                            ),
                            if (p.availabilityNotes != null) ...[
                              const SizedBox(height: 18),
                              const Text('Availability',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: HomeStyle.textPrimary)),
                              const SizedBox(height: 6),
                              Text(p.availabilityNotes!,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      height: 1.4,
                                      color: HomeStyle.textSecondary)),
                            ],
                            const SizedBox(height: 22),
                            _RequestPracticeForm(
                                partnerId: p.profileId,
                                defaultRole: p.targetRole),
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
  const _Header({required this.profileId});

  final String profileId;

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
            child: Text('Practice Partner',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary)),
          ),
          ReportActionButton(
              targetType: ReportTargetType.interviewPracticeProfile,
              targetId: profileId),
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
      child: FormSectionCard(
        icon: Icons.record_voice_over_outlined,
        title: 'Request a practice session',
        children: [
          TextFormField(
            controller: _roleController,
            style: const TextStyle(color: HomeStyle.textPrimary),
            decoration: darkInputDecoration('Role to practice'),
            validator: (v) => Validators.required(v, fieldName: 'Target role'),
          ),
          TextFormField(
            controller: _messageController,
            maxLines: 3,
            style: const TextStyle(color: HomeStyle.textPrimary),
            decoration: darkInputDecoration('Message (optional)'),
          ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: isSaving ? null : _submit,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isSaving ? null : HomeStyle.brandGradient,
                  color: isSaving ? HomeStyle.cardBase : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: HomeStyle.purple),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.record_voice_over_outlined,
                              size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Request practice',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
