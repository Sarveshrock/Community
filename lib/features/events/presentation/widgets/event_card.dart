import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/app_router.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../domain/entities/event.dart';

/// Compact discovery card (spec: "keep cards compact" while still
/// communicating cover/title/category/date/location/organizer/
/// participants/price at a glance).
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event});

  final CommunityEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HomeStyle.cardBase.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(RoutePaths.eventDetailOf(event.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: HomeStyle.brandGradient,
                        image: event.coverImageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(event.coverImageUrl!), fit: BoxFit.cover)
                            : null,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(eventTypeLabel(event.eventType),
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: event.isFree
                              ? const Color(0xFF10D9A0).withValues(alpha: 0.85)
                              : Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          event.isFree ? 'Free' : '${event.currency} ${event.price?.toStringAsFixed(0) ?? '—'}',
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        style: const TextStyle(
                            color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 14.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: HomeStyle.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            DateFormat.MMMd().add_jm().format(event.startsAt.toLocal()),
                            style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(event.isOnline ? Icons.videocam_outlined : Icons.place_outlined,
                            size: 12, color: HomeStyle.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.isOnline ? 'Online' : (event.city ?? event.location ?? 'TBA'),
                            style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.hostName ?? 'Community host',
                            style: const TextStyle(color: HomeStyle.purple, fontSize: 11.5, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.people_alt_outlined, size: 12, color: HomeStyle.textSecondary),
                        const SizedBox(width: 3),
                        Text('${event.attendeeCount}',
                            style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
