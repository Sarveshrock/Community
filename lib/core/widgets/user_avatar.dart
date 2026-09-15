import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/presentation/providers/profile_providers.dart' show avatarSignedUrlProvider;
import 'generic_avatar.dart';

/// The single place every profile photo in Communeo renders through — home,
/// discover, search, communities, events, teams, mentors, jobs, intents,
/// posts, comments, chat, notifications, connections, and anywhere else a
/// person's avatar appears. Centralizing here (rather than each screen
/// deciding for itself) is what makes photo-privacy enforcement consistent
/// app-wide: a real photo lives in the private `avatars` Storage bucket as a
/// bare path (`<profileId>/avatar.ext`), and this widget is the only place
/// that resolves that path to a signed URL — which is also, not
/// incidentally, the only place the actual authorization check
/// (`can_view_profile_photo`, enforced by Storage RLS — see
/// 0049_profile_photo_privacy.sql) gets a chance to deny the request. An
/// unauthorized viewer's signed-URL fetch simply fails, and this widget
/// falls back to initials exactly as it would for a missing photo — never a
/// blurred or partial image, never the real URL exposed to begin with.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    this.avatarUrl,
    required this.name,
    this.radius = 24,
  });

  final String? avatarUrl;
  final String name;
  final double radius;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// A resolvable image URL (`http`/`https`) vs. a bare Storage path like
  /// `<profileId>/avatar.jpg` — every row written after
  /// 0049_profile_photo_privacy.sql stores the latter; this also tolerates
  /// any not-yet-backfilled legacy row that still holds a full URL.
  bool _looksLikeUrl(String value) => value.startsWith('http://') || value.startsWith('https://');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // A chosen illustrated avatar (see generic_avatar.dart) lives in this
    // same `avatar_url` field as a sentinel string — every existing caller
    // of UserAvatar renders it correctly with no changes on their part.
    if (isGenericAvatarUrl(avatarUrl)) {
      final option = genericAvatarFromUrl(avatarUrl!);
      if (option != null) {
        return ClipOval(child: GenericAvatar(option: option, radius: radius));
      }
    }

    final raw = avatarUrl;
    if (raw == null || raw.isEmpty) {
      return _InitialsAvatar(initials: _initials, radius: radius);
    }

    if (_looksLikeUrl(raw)) {
      return _NetworkAvatar(url: raw, initials: _initials, radius: radius, theme: theme);
    }

    // Bare storage path — resolve via a signed URL, which is also where an
    // unauthorized viewer gets turned away (see class doc comment above).
    final signedUrlAsync = ref.watch(avatarSignedUrlProvider(raw));
    return signedUrlAsync.when(
      loading: () => _InitialsAvatar(initials: _initials, radius: radius),
      error: (_, __) => _InitialsAvatar(initials: _initials, radius: radius),
      data: (url) => _NetworkAvatar(url: url, initials: _initials, radius: radius, theme: theme),
    );
  }
}

class _NetworkAvatar extends StatelessWidget {
  const _NetworkAvatar({required this.url, required this.initials, required this.radius, required this.theme});

  final String url;
  final String initials;
  final double radius;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _InitialsAvatar(initials: initials, radius: radius),
          placeholder: (_, __) => _InitialsAvatar(initials: initials, radius: radius),
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials, required this.radius});

  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(
        initials,
        style: TextStyle(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}
