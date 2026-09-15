import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
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
      appBar: AppBar(
        title: const Text('Referral Offer'),
        actions: [
          ReportActionButton(
              targetType: ReportTargetType.referralOffer, targetId: offerId),
        ],
      ),
      body: offerAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (offer) {
          final isOwner = offer.profileId == myId;
          return ResponsiveCenter(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(
                          avatarUrl: offer.avatarUrl,
                          name: offer.fullName ?? '?',
                          radius: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(offer.companyName,
                                style: context.textStyles.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            if (offer.fullName != null)
                              Text(offer.fullName!,
                                  style: context.textStyles.bodyMedium?.copyWith(
                                      color: context.colors.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (offer.roleTitle != null) ...[
                    const SizedBox(height: 12),
                    Chip(label: Text(offer.roleTitle!)),
                  ],
                  if (offer.notes != null) ...[
                    const SizedBox(height: 16),
                    Text(offer.notes!),
                  ],
                  const SizedBox(height: 24),
                  if (isOwner)
                    _OwnerActions(offer: offer)
                  else
                    _RequestReferralForm(offerId: offerId),
                ],
              ),
            ),
          );
        },
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
            Text('This is your offer',
                style: context.textStyles.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Row(
              children: [
                Text(offer.isActive ? 'Active' : 'Paused'),
                Switch(
                  value: offer.isActive,
                  onChanged: isLoading
                      ? null
                      : (v) => ref
                          .read(referralControllerProvider.notifier)
                          .setOfferActive(offer.id, v),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Requests',
            style: context.textStyles.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        requestsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('Could not load requests'),
          data: (requests) {
            if (requests.isEmpty) return const Text('No requests yet.');
            return Column(
              children: [
                for (final r in requests)
                  _ReceivedRequestCard(offerId: offer.id, request: r),
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
        actions = Row(
          children: [
            FilledButton(
              onPressed: () =>
                  controller.respondToRequest(request.id, offerId, accept: true),
              child: const Text('Accept'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () =>
                  controller.respondToRequest(request.id, offerId, accept: false),
              child: const Text('Decline'),
            ),
          ],
        );
        break;
      case ReferralRequestStatus.resumeSubmitted:
        actions = FilledButton(
          onPressed: () => controller.markSubmitted(request.id, offerId),
          child: const Text('Mark referral submitted'),
        );
        break;
      case ReferralRequestStatus.referralSubmitted:
      case ReferralRequestStatus.interviewing:
        actions = Wrap(
          spacing: 8,
          children: [
            if (request.status != ReferralRequestStatus.interviewing)
              OutlinedButton(
                onPressed: () =>
                    controller.updateOutcome(request.id, offerId, 'interviewing'),
                child: const Text('Interviewing'),
              ),
            FilledButton(
              onPressed: () =>
                  controller.updateOutcome(request.id, offerId, 'hired'),
              child: const Text('Hired'),
            ),
            OutlinedButton(
              onPressed: () =>
                  controller.updateOutcome(request.id, offerId, 'rejected'),
              child: const Text('Rejected'),
            ),
          ],
        );
        break;
      default:
        actions = const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: UserAvatar(
                  avatarUrl: request.requesterAvatarUrl,
                  name: request.requesterName ?? '?'),
              title: Text(request.requesterName ?? 'Community member'),
              subtitle: Text(request.jobTitle),
              trailing: Chip(
                  label: Text(request.status.label),
                  visualDensity: VisualDensity.compact),
            ),
            if (request.message != null) ...[
              const SizedBox(height: 4),
              Text(request.message!),
            ],
            if (request.resumeUrl != null) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                icon: const Icon(Icons.description_outlined),
                label: const Text('View resume'),
                onPressed: () => launchUrl(Uri.parse(request.resumeUrl!)),
              ),
            ],
            const SizedBox(height: 8),
            actions,
          ],
        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Request a referral',
              style: context.textStyles.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _jobTitleController,
            decoration: const InputDecoration(labelText: 'Job title you\'re targeting'),
            validator: (v) => Validators.required(v, fieldName: 'Job title'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _jobUrlController,
            decoration: const InputDecoration(labelText: 'Job posting URL (optional)'),
            validator: Validators.url,
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
              icon: const Icon(Icons.send_outlined),
              label: const Text('Request referral'),
              onPressed: isSaving ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}
