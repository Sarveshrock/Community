import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../moderation/presentation/widgets/report_action_button.dart';
import '../providers/referral_providers.dart';

class ReferralOfferDetailScreen extends ConsumerWidget {
  const ReferralOfferDetailScreen({super.key, required this.offerId});

  final String offerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offerAsync = ref.watch(referralOfferDetailProvider(offerId));
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
                  _Header(offerId: offerId),
                  Expanded(
                    child: offerAsync.when(
                      loading: () => const LoadingState(),
                      error: (e, _) => ErrorState(message: e.toString()),
                      data: (offer) {
                        final isOwner = offer.profileId == myId;
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
                                        avatarUrl: offer.avatarUrl,
                                        name: offer.fullName ?? '?',
                                        radius: 28),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(offer.companyName,
                                            style: const TextStyle(
                                                fontSize: 19,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    HomeStyle.textPrimary)),
                                        if (offer.fullName != null) ...[
                                          const SizedBox(height: 2),
                                          Text(offer.fullName!,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color: HomeStyle
                                                      .textSecondary)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (offer.roleTitle != null) ...[
                                const SizedBox(height: 12),
                                HomeChip(offer.roleTitle!,
                                    accent: HomeStyle.blue),
                              ],
                              if (offer.notes != null) ...[
                                const SizedBox(height: 14),
                                Text(offer.notes!,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        height: 1.5,
                                        color: HomeStyle.textPrimary)),
                              ],
                              const SizedBox(height: 22),
                              if (isOwner)
                                _OwnerActions(offer: offer)
                              else
                                _RequestReferralForm(offerId: offerId),
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
  const _Header({required this.offerId});

  final String offerId;

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
            child: Text('Referral Offer',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary)),
          ),
          ReportActionButton(
              targetType: ReportTargetType.referralOffer, targetId: offerId),
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

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: HomeStyle.brandGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton(
      {required this.label, required this.onTap, this.color});

  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? HomeStyle.textSecondary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tint.withValues(alpha: 0.5)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: tint, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ),
    );
  }
}

class _OwnerActions extends ConsumerWidget {
  const _OwnerActions({required this.offer});

  final ReferralOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(receivedReferralRequestsProvider(offer.id));
    final isLoading = ref.watch(referralControllerProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('This is your offer',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: HomeStyle.textPrimary)),
            Row(
              children: [
                Text(offer.isActive ? 'Active' : 'Paused',
                    style: const TextStyle(
                        fontSize: 12.5, color: HomeStyle.textSecondary)),
                Switch(
                  value: offer.isActive,
                  onChanged: isLoading
                      ? null
                      : (v) => ref
                          .read(referralControllerProvider.notifier)
                          .setOfferActive(offer.id, v),
                  activeThumbColor: Colors.white,
                  activeTrackColor: HomeStyle.purple,
                  inactiveThumbColor: HomeStyle.textSecondary,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Requests',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: HomeStyle.textPrimary)),
        const SizedBox(height: 10),
        requestsAsync.when(
          loading: () =>
              const LinearProgressIndicator(color: HomeStyle.purple),
          error: (_, __) => const Text('Could not load requests',
              style: TextStyle(color: HomeStyle.textSecondary)),
          data: (requests) {
            if (requests.isEmpty) {
              return const Text('No requests yet.',
                  style: TextStyle(
                      fontSize: 13, color: HomeStyle.textSecondary));
            }
            return Column(
              children: [
                for (final r in requests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child:
                        _ReceivedRequestCard(offerId: offer.id, request: r),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReceivedRequestCard extends ConsumerWidget {
  const _ReceivedRequestCard({required this.offerId, required this.request});

  final String offerId;
  final ReferralRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(referralControllerProvider.notifier);

    Widget actions;
    switch (request.status) {
      case ReferralRequestStatus.pending:
        actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _GradientButton(
              label: 'Accept',
              onTap: () =>
                  controller.respondToRequest(request.id, offerId, accept: true),
            ),
            _OutlineActionButton(
              label: 'Decline',
              onTap: () =>
                  controller.respondToRequest(request.id, offerId, accept: false),
            ),
          ],
        );
      case ReferralRequestStatus.resumeSubmitted:
        actions = _GradientButton(
          label: 'Mark referral submitted',
          onTap: () => controller.markSubmitted(request.id, offerId),
        );
      case ReferralRequestStatus.referralSubmitted:
      case ReferralRequestStatus.interviewing:
        actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (request.status != ReferralRequestStatus.interviewing)
              _OutlineActionButton(
                label: 'Interviewing',
                color: HomeStyle.blue,
                onTap: () =>
                    controller.updateOutcome(request.id, offerId, 'interviewing'),
              ),
            _GradientButton(
              label: 'Hired',
              onTap: () =>
                  controller.updateOutcome(request.id, offerId, 'hired'),
            ),
            _OutlineActionButton(
              label: 'Rejected',
              color: HomeStyle.pink,
              onTap: () =>
                  controller.updateOutcome(request.id, offerId, 'rejected'),
            ),
          ],
        );
      default:
        actions = const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomeStyle.cardBase,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                  avatarUrl: request.requesterAvatarUrl,
                  name: request.requesterName ?? '?'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.requesterName ?? 'Community member',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: HomeStyle.textPrimary)),
                    const SizedBox(height: 2),
                    Text(request.jobTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: HomeStyle.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              HomeChip(request.status.label, accent: HomeStyle.blue),
            ],
          ),
          if (request.message != null) ...[
            const SizedBox(height: 8),
            Text(request.message!,
                style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: HomeStyle.textPrimary)),
          ],
          if (request.resumeUrl != null) ...[
            const SizedBox(height: 6),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => launchUrl(Uri.parse(request.resumeUrl!)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_outlined,
                          size: 16, color: HomeStyle.purple),
                      SizedBox(width: 6),
                      Text('View resume',
                          style: TextStyle(
                              color: HomeStyle.purple,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          actions,
        ],
      ),
    );
  }
}

class _RequestReferralForm extends ConsumerStatefulWidget {
  const _RequestReferralForm({required this.offerId});

  final String offerId;

  @override
  ConsumerState<_RequestReferralForm> createState() =>
      _RequestReferralFormState();
}

class _RequestReferralFormState extends ConsumerState<_RequestReferralForm> {
  final _formKey = GlobalKey<FormState>();
  final _jobTitleController = TextEditingController();
  final _jobUrlController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _jobTitleController.dispose();
    _jobUrlController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(referralControllerProvider.notifier).requestReferral(
          widget.offerId,
          jobTitle: _jobTitleController.text.trim(),
          jobUrl: _jobUrlController.text.trim().isEmpty
              ? null
              : _jobUrlController.text.trim(),
          message: _messageController.text.trim().isEmpty
              ? null
              : _messageController.text.trim(),
        );
    if (!mounted) return;
    context.showSnack(
        success ? 'Referral request sent' : 'Could not send request — you may already have one pending',
        isError: !success);
    if (success) {
      _jobTitleController.clear();
      _jobUrlController.clear();
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(referralControllerProvider).isLoading;

    return Form(
      key: _formKey,
      child: FormSectionCard(
        icon: Icons.send_outlined,
        title: 'Request a referral',
        children: [
          TextFormField(
            controller: _jobTitleController,
            style: const TextStyle(color: HomeStyle.textPrimary),
            decoration: darkInputDecoration('Job title you\'re targeting'),
            validator: (v) => Validators.required(v, fieldName: 'Job title'),
          ),
          TextFormField(
            controller: _jobUrlController,
            style: const TextStyle(color: HomeStyle.textPrimary),
            decoration: darkInputDecoration('Job posting URL (optional)'),
            validator: Validators.url,
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
                          Icon(Icons.send_outlined,
                              size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Request referral',
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
