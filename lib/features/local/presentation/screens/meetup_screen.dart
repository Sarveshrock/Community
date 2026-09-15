import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetupsAsync =
        ref.watch(meetupsForConnectionProvider(localConnectionId));
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final isLoading = ref.watch(localControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meetup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) =>
                  _SuggestMeetupSheet(localConnectionId: localConnectionId),
            ),
          ),
        ],
      ),
      body: ResponsiveCenter(
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
                onAction: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) =>
                      _SuggestMeetupSheet(localConnectionId: localConnectionId),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: meetups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final m = meetups[i];
                final isMine = m.suggestedBy == myId;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                                    style: context.textStyles.titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700))),
                            Chip(
                                label: Text(m.status),
                                visualDensity: VisualDensity.compact),
                          ],
                        ),
                        if (m.suggestedArea != null ||
                            m.suggestedPlaceName != null) ...[
                          const SizedBox(height: 6),
                          Text([m.suggestedPlaceName, m.suggestedArea]
                              .whereType<String>()
                              .join(', ')),
                        ],
                        if (m.suggestedAt != null) ...[
                          const SizedBox(height: 4),
                          Text(DateFormat.yMMMd()
                              .add_jm()
                              .format(m.suggestedAt!)),
                        ],
                        if (m.message != null && m.message!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(m.message!,
                              style: context.textStyles.bodySmall?.copyWith(
                                  color: context.colors.onSurfaceVariant)),
                        ],
                        if (!isMine && m.status == 'pending') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.localAccent),
                                  onPressed: isLoading
                                      ? null
                                      : () => ref
                                          .read(
                                              localControllerProvider.notifier)
                                          .respondToMeetup(
                                              localConnectionId, m.id,
                                              accept: true),
                                  child: const Text('Accept'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isLoading
                                      ? null
                                      : () => ref
                                          .read(
                                              localControllerProvider.notifier)
                                          .respondToMeetup(
                                              localConnectionId, m.id,
                                              accept: false),
                                  child: const Text('Decline'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
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
          Text('Suggest a meetup',
              style: context.textStyles.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final activity in _meetupActivities)
                ChoiceChip(
                  label: Text(activity),
                  selected: _activity == activity,
                  onSelected: (_) => setState(() => _activity = activity),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _placeController,
              decoration: const InputDecoration(labelText: 'Place (optional)')),
          const SizedBox(height: 12),
          TextField(
              controller: _areaController,
              decoration: const InputDecoration(labelText: 'Approximate area')),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_dateTime == null
                ? 'Pick date & time'
                : DateFormat.yMMMd().add_jm().format(_dateTime!)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _pickDateTime,
          ),
          TextField(
              controller: _messageController,
              decoration:
                  const InputDecoration(labelText: 'Message (optional)')),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.localAccent),
              onPressed: _submit,
              child: const Text('Send suggestion'),
            ),
          ),
        ],
      ),
    );
  }
}
