import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/local_providers.dart';

const _meetupActivities = [
  'Coffee',
  'Walk',
  'Dinner',
  'Gaming',
  'Movie',
  'City exploration'
];

/// Suggest / accept a 1-to-1 meetup (spec sections 3.1, 35, 64). Only
/// reachable once a local connection is accepted — both people must
/// explicitly agree, and it is always exactly two people.
class MeetupScreen extends ConsumerWidget {
  const MeetupScreen({super.key, required this.localConnectionId});

  final String localConnectionId;

  void _openSuggestSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeStyle.cardBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SuggestMeetupSheet(localConnectionId: localConnectionId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetupsAsync =
        ref.watch(meetupsForConnectionProvider(localConnectionId));
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final isLoading = ref.watch(localControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  _Header(onSuggest: () => _openSuggestSheet(context)),
                  Expanded(
                    child: meetupsAsync.when(
                      loading: () => const LoadingState(),
                      error: (e, _) => ErrorState(message: e.toString()),
                      data: (meetups) {
                        if (meetups.isEmpty) {
                          return EmptyState(
                            icon: Icons.event_available_outlined,
                            title: 'No meetup suggested yet',
                            message:
                                'Suggest an activity, area, and time once you\'re both comfortable.',
                            actionLabel: 'Suggest a meetup',
                            onAction: () => _openSuggestSheet(context),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: meetups.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final m = meetups[i];
                            final isMine = m.suggestedBy == myId;
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: HomeStyle.cardBase,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.06)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.celebration_outlined,
                                          color: AppColors.localAccent),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(m.activityType,
                                              style: const TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      HomeStyle.textPrimary))),
                                      HomeChip(m.status,
                                          accent: AppColors.localAccent),
                                    ],
                                  ),
                                  if (m.suggestedArea != null ||
                                      m.suggestedPlaceName != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                        [
                                          m.suggestedPlaceName,
                                          m.suggestedArea
                                        ].whereType<String>().join(', '),
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            color: HomeStyle.textSecondary)),
                                  ],
                                  if (m.suggestedAt != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                        DateFormat.yMMMd()
                                            .add_jm()
                                            .format(m.suggestedAt!),
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            color: HomeStyle.textSecondary)),
                                  ],
                                  if (m.message != null &&
                                      m.message!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(m.message!,
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            height: 1.4,
                                            color: HomeStyle.textPrimary)),
                                  ],
                                  if (!isMine && m.status == 'pending') ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Material(
                                            color: Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: isLoading
                                                  ? null
                                                  : () => ref
                                                      .read(
                                                          localControllerProvider
                                                              .notifier)
                                                      .respondToMeetup(
                                                          localConnectionId,
                                                          m.id,
                                                          accept: true),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 12),
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color:
                                                      AppColors.localAccent,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12),
                                                ),
                                                child: const Text('Accept',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700)),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Material(
                                            color: Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: isLoading
                                                  ? null
                                                  : () => ref
                                                      .read(
                                                          localControllerProvider
                                                              .notifier)
                                                      .respondToMeetup(
                                                          localConnectionId,
                                                          m.id,
                                                          accept: false),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 12),
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12),
                                                  border: Border.all(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.16)),
                                                ),
                                                child: const Text('Decline',
                                                    style: TextStyle(
                                                        color: HomeStyle
                                                            .textSecondary,
                                                        fontWeight:
                                                            FontWeight.w700)),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
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
  const _Header({required this.onSuggest});

  final VoidCallback onSuggest;

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
            child: Text('Meetup',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary)),
          ),
          _IconButton(
              icon: Icons.add_rounded,
              tooltip: 'Suggest a meetup',
              highlighted: true,
              onTap: onSuggest),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.highlighted = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: highlighted ? AppColors.localAccent : HomeStyle.cardBase,
          borderRadius: BorderRadius.circular(13),
          border: highlighted
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: Icon(icon,
                color: highlighted ? Colors.white : HomeStyle.textPrimary,
                size: 21),
          ),
        ),
      ),
    );
  }
}

class _SuggestMeetupSheet extends ConsumerStatefulWidget {
  const _SuggestMeetupSheet({required this.localConnectionId});
  final String localConnectionId;

  @override
  ConsumerState<_SuggestMeetupSheet> createState() =>
      _SuggestMeetupSheetState();
}

class _SuggestMeetupSheetState extends ConsumerState<_SuggestMeetupSheet> {
  String _activity = _meetupActivities.first;
  final _areaController = TextEditingController();
  final _placeController = TextEditingController();
  final _messageController = TextEditingController();
  DateTime? _dateTime;

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() => _dateTime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    final success = await ref
        .read(localControllerProvider.notifier)
        .suggestMeetup(widget.localConnectionId, {
      'activity_type': _activity,
      'suggested_area': _areaController.text.trim().isEmpty
          ? null
          : _areaController.text.trim(),
      'suggested_place_name': _placeController.text.trim().isEmpty
          ? null
          : _placeController.text.trim(),
      'suggested_at': _dateTime?.toIso8601String(),
      'message': _messageController.text.trim().isEmpty
          ? null
          : _messageController.text.trim(),
    });
    if (success && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _areaController.dispose();
    _placeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          const Text('Suggest a meetup',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HomeStyle.textPrimary)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final activity in _meetupActivities)
                _ActivityChoiceChip(
                  label: activity,
                  selected: _activity == activity,
                  onTap: () => setState(() => _activity = activity),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
              controller: _placeController,
              style: const TextStyle(color: HomeStyle.textPrimary),
              decoration: darkInputDecoration('Place (optional)')),
          const SizedBox(height: 12),
          TextField(
              controller: _areaController,
              style: const TextStyle(color: HomeStyle.textPrimary),
              decoration: darkInputDecoration('Approximate area')),
          const SizedBox(height: 12),
          Material(
            color: HomeStyle.cardBase,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickDateTime,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          _dateTime == null
                              ? 'Pick date & time'
                              : DateFormat.yMMMd().add_jm().format(_dateTime!),
                          style: TextStyle(
                              color: _dateTime == null
                                  ? HomeStyle.textSecondary
                                  : HomeStyle.textPrimary)),
                    ),
                    const Icon(Icons.calendar_month_outlined,
                        color: HomeStyle.textSecondary, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _messageController,
              style: const TextStyle(color: HomeStyle.textPrimary),
              decoration: darkInputDecoration('Message (optional)')),
          const SizedBox(height: 18),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _submit,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.localAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('Send suggestion',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityChoiceChip extends StatelessWidget {
  const _ActivityChoiceChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.localAccent.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
                color: selected
                    ? AppColors.localAccent
                    : Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.localAccent : HomeStyle.textSecondary)),
        ),
      ),
    );
  }
}
