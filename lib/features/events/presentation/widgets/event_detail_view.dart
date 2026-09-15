import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/event_agenda_item.dart';
import '../../domain/entities/event_speaker.dart';
import '../../domain/event_action_state.dart';

/// The event's full rendering — shared by the real, provider-backed
/// [EventDetailScreen] and the create-flow's live Preview step (spec:
/// "the preview should look almost identical to the actual Event Detail
/// Page"), so the two can never visually drift apart. Every dynamic bit
/// (join action, attendee avatars, organizer controls) is passed in rather
/// than fetched here, so this widget never needs to know whether it's
/// looking at a real, saved event or a form's current draft.
class EventDetailView extends StatelessWidget {
  const EventDetailView({
    super.key,
    required this.event,
    this.agenda = const [],
    this.speakers = const [],
    this.actionState,
    this.onPrimaryAction,
    this.isActionLoading = false,
    this.attendeeAvatarUrls = const [],
    this.organizerControls,
    this.coverImageBytesPreview,
  });

  final CommunityEvent event;
  final List<EventAgendaItem> agenda;
  final List<EventSpeaker> speakers;

  /// Null in preview mode — shows a static "Preview" badge instead of a
  /// real CTA.
  final EventActionState? actionState;
  final VoidCallback? onPrimaryAction;
  final bool isActionLoading;
  final List<String?> attendeeAvatarUrls;
  final Widget? organizerControls;

  /// Locally-picked cover bytes shown before the event (and its uploaded
  /// cover) actually exists yet — the create flow's preview only.
  final ImageProvider? coverImageBytesPreview;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Cover(event: event, imageOverride: coverImageBytesPreview),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.isCancelled) _CancelledBanner(reason: event.cancellationReason),
              _PrimaryActionRow(
                actionState: actionState,
                onPrimaryAction: onPrimaryAction,
                isLoading: isActionLoading,
              ),
              const SizedBox(height: 18),
              _QuickInfoGrid(event: event),
              const SizedBox(height: 20),
              if ((event.description ?? '').isNotEmpty) ...[
                const _SectionHeader('About this event'),
                Text(event.description!,
                    style: const TextStyle(color: HomeStyle.textSecondary, height: 1.5)),
                const SizedBox(height: 20),
              ],
              if (agenda.isNotEmpty) ...[
                const _SectionHeader('Agenda'),
                _AgendaTimeline(items: agenda),
                const SizedBox(height: 20),
              ],
              if (speakers.isNotEmpty) ...[
                const _SectionHeader('Speakers'),
                _SpeakersRow(speakers: speakers),
                const SizedBox(height: 20),
              ],
              if (event.audience.isNotEmpty) ...[
                const _SectionHeader('Who should join'),
                _ChipWrap(items: event.audience, accent: HomeStyle.blue),
                const SizedBox(height: 20),
              ],
              if (event.whatToBring.isNotEmpty || (event.prerequisites ?? '').isNotEmpty) ...[
                const _SectionHeader('Requirements'),
                if (event.whatToBring.isNotEmpty) _ChipWrap(items: event.whatToBring, accent: HomeStyle.amber),
                if ((event.prerequisites ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(event.prerequisites!, style: const TextStyle(color: HomeStyle.textSecondary)),
                ],
                const SizedBox(height: 20),
              ],
              if (event.benefits.isNotEmpty) ...[
                const _SectionHeader('What you\'ll get'),
                _ChipWrap(items: event.benefits, accent: HomeStyle.cyan),
                const SizedBox(height: 20),
              ],
              const _SectionHeader('Organizer'),
              _OrganizerCard(event: event),
              if (organizerControls != null) ...[
                const SizedBox(height: 12),
                organizerControls!,
              ],
              if (attendeeAvatarUrls.isNotEmpty || event.attendeeCount > 0) ...[
                const SizedBox(height: 20),
                const _SectionHeader('Attendees'),
                _AttendeesRow(avatarUrls: attendeeAvatarUrls, count: event.attendeeCount),
              ],
              const SizedBox(height: 20),
              const _SectionHeader('Location'),
              _LocationSection(event: event),
            ],
          ),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.event, this.imageOverride});

  final CommunityEvent event;
  final ImageProvider? imageOverride;

  @override
  Widget build(BuildContext context) {
    final image = imageOverride ??
        (event.coverImageUrl != null ? NetworkImage(event.coverImageUrl!) : null);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: HomeStyle.brandGradient,
              image: image != null ? DecorationImage(image: image, fit: BoxFit.cover) : null,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.75)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(eventTypeLabel(event.eventType),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                Text(event.title,
                    style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat.MMMd().add_jm().format(event.startsAt.toLocal())} · ${_locationSummary(event)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _locationSummary(CommunityEvent event) {
  final modeLabel = event.mode[0].toUpperCase() + event.mode.substring(1);
  if (event.isOnline) return modeLabel;
  return [event.city, modeLabel].whereType<String>().join(' · ');
}

class _CancelledBanner extends StatelessWidget {
  const _CancelledBanner({this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFB7185).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFB7185).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_busy_rounded, color: Color(0xFFFB7185), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reason == null || reason!.isEmpty ? 'This event has been cancelled.' : 'Cancelled: $reason',
              style: const TextStyle(color: Color(0xFFFB7185), fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionRow extends StatelessWidget {
  const _PrimaryActionRow({required this.actionState, required this.onPrimaryAction, required this.isLoading});

  final EventActionState? actionState;
  final VoidCallback? onPrimaryAction;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (actionState == null) {
      return Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: const Text('Preview — actions are disabled',
            style: TextStyle(color: HomeStyle.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
      );
    }
    if (actionState == EventActionState.host || actionState == EventActionState.none) {
      return const SizedBox.shrink();
    }

    final state = actionState!;
    final enabled = state.isActionable && !isLoading;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: enabled ? onPrimaryAction : null,
          child: Container(
            decoration: BoxDecoration(
              gradient: enabled ? HomeStyle.brandGradient : null,
              color: enabled ? null : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(100),
              boxShadow: enabled ? HomeStyle.glow(HomeStyle.purple, opacity: 0.3) : null,
            ),
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    state.label,
                    style: TextStyle(
                      color: enabled ? Colors.white : HomeStyle.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
    );
  }
}

class _QuickInfoGrid extends StatelessWidget {
  const _QuickInfoGrid({required this.event});

  final CommunityEvent event;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (Icons.calendar_today_rounded, 'Date', DateFormat.yMMMd().format(event.startsAt.toLocal())),
      (Icons.access_time_rounded, 'Time',
          '${DateFormat.jm().format(event.startsAt.toLocal())} ${event.timezone}'),
      (Icons.place_outlined, 'Location', event.isOnline ? 'Online' : (event.city ?? '—')),
      (Icons.public_rounded, 'Mode', event.mode[0].toUpperCase() + event.mode.substring(1)),
      (Icons.people_alt_outlined, 'Participants',
          event.maxParticipants == null ? '${event.attendeeCount}' : '${event.attendeeCount}/${event.maxParticipants}'),
      (Icons.sell_outlined, 'Price', event.isFree ? 'Free' : '${event.currency} ${event.price?.toStringAsFixed(0) ?? '—'}'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.8,
      children: [
        for (final (icon, label, value) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: HomeStyle.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 10.5, color: HomeStyle.textSecondary)),
                      Text(value,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AgendaTimeline extends StatelessWidget {
  const _AgendaTimeline({required this.items});

  final List<EventAgendaItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(DateFormat.jm().format(item.startsAt.toLocal()),
                        style: const TextStyle(fontSize: 12, color: HomeStyle.textSecondary)),
                  ),
                  Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: HomeStyle.brandGradient),
                      ),
                      const Expanded(child: VerticalDivider(color: Colors.white24, thickness: 1)),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              style: const TextStyle(
                                  color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                          if ((item.description ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(item.description!,
                                  style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12)),
                            ),
                          if (item.speakerDisplayName != null || item.room != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                [item.speakerDisplayName, item.room].whereType<String>().join(' · '),
                                style: const TextStyle(color: HomeStyle.purple, fontSize: 11.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SpeakersRow extends StatelessWidget {
  const _SpeakersRow({required this.speakers});

  final List<EventSpeaker> speakers;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: speakers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = speakers[i];
          return Container(
            width: 120,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(avatarUrl: s.profileAvatarUrl, name: s.displayName, radius: 22),
                const SizedBox(height: 8),
                Text(s.displayName,
                    style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if ((s.role ?? '').isNotEmpty)
                  Text(s.role!,
                      style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.items, required this.accent});

  final List<String> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Text(item, style: TextStyle(fontSize: 12.5, color: accent, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class _OrganizerCard extends StatelessWidget {
  const _OrganizerCard({required this.event});

  final CommunityEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          UserAvatar(avatarUrl: event.hostAvatarUrl, name: event.hostName ?? '?', radius: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.hostName ?? 'Community member',
                    style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                const Text('Host', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendeesRow extends StatelessWidget {
  const _AttendeesRow({required this.avatarUrls, required this.count});

  final List<String?> avatarUrls;
  final int count;

  @override
  Widget build(BuildContext context) {
    final preview = avatarUrls.take(6).toList();
    return Row(
      children: [
        SizedBox(
          height: 36,
          width: preview.isEmpty ? 0 : 22.0 * preview.length + 14,
          child: Stack(
            children: [
              for (var i = 0; i < preview.length; i++)
                Positioned(
                  left: i * 22.0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: HomeStyle.background, width: 2),
                    ),
                    child: UserAvatar(avatarUrl: preview[i], name: '?', radius: 16),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text('$count attending', style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
      ],
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.event});

  final CommunityEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.isOnline || event.isHybrid) ...[
            Row(
              children: [
                const Icon(Icons.videocam_outlined, size: 18, color: HomeStyle.blue),
                const SizedBox(width: 8),
                Text(event.meetingPlatform ?? 'Online',
                    style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              event.meetingUrl != null
                  ? 'Joining details available after you register.'
                  : 'The host hasn\'t added a meeting link yet.',
              style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5),
            ),
            if (event.isHybrid) const SizedBox(height: 12),
          ],
          if (event.isOffline || event.isHybrid) ...[
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 18, color: HomeStyle.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(event.venueName ?? event.location ?? 'Venue to be announced',
                      style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if ((event.city ?? event.state) != null) ...[
              const SizedBox(height: 4),
              Text([event.city, event.state].whereType<String>().join(', '),
                  style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
            ],
          ],
        ],
      ),
    );
  }
}
