import 'package:flutter/material.dart';

import '../../../home/presentation/widgets/home_style.dart';
import '../../domain/entities/community.dart';

/// Compact discovery-list card for a community — logo, name, tagline,
/// topics, member count, type, and access type. Extracted from
/// `communities_list_screen.dart`'s old inline `ListTile` and redesigned to
/// match Communeo's dark visual language.
class CommunityCard extends StatelessWidget {
  const CommunityCard({super.key, required this.community, required this.onTap});

  final Community community;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final topTopics = community.topicNames.take(3).toList();
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HomeStyle.cardBase,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: community.logoUrl == null ? HomeStyle.brandGradient : null,
                  image: community.logoUrl != null ? DecorationImage(image: NetworkImage(community.logoUrl!), fit: BoxFit.cover) : null,
                ),
                alignment: Alignment.center,
                child: community.logoUrl == null
                    ? Text(community.name.isEmpty ? '?' : community.name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(community.name,
                        style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if ((community.tagline ?? community.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(community.tagline ?? community.description!,
                          style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    if (topTopics.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(topTopics.join(' • '),
                          style: const TextStyle(color: HomeStyle.purple, fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Badge('${community.memberCount} member${community.memberCount == 1 ? '' : 's'}'),
                        _Badge(communityTypeLabel(community.communityType)),
                        if (!community.isPublic) _Badge(communityAccessTypeLabel(community.accessType)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: HomeStyle.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10.5, color: HomeStyle.textSecondary, fontWeight: FontWeight.w600)),
    );
  }
}
