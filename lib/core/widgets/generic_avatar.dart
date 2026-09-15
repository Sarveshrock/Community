import 'package:flutter/material.dart';

/// A small built-in catalog of illustrated avatars for people who don't want
/// to upload a real photo. Each is a gradient circle + icon, rendered
/// entirely in Flutter — no bundled image assets, no network fetch, nothing
/// to keep in sync with a design file.
///
/// Chosen avatars are stored as a plain sentinel string in the *same*
/// `profiles.avatar_url` column real photos already use — no schema change,
/// and every existing "show `profile.avatarUrl`" call site keeps working
/// unmodified once it renders through [UserAvatar] (the one place that
/// interprets the sentinel).
class GenericAvatarOption {
  const GenericAvatarOption(this.icon, this.colors);

  final IconData icon;
  final List<Color> colors;
}

const genericAvatarCatalog = <GenericAvatarOption>[
  GenericAvatarOption(Icons.rocket_launch_rounded, [Color(0xFF4C8DFF), Color(0xFF9D5CFF)]),
  GenericAvatarOption(Icons.emoji_nature_rounded, [Color(0xFF10D9A0), Color(0xFF22D3EE)]),
  GenericAvatarOption(Icons.star_rounded, [Color(0xFFF59E0B), Color(0xFFEC4899)]),
  GenericAvatarOption(Icons.bolt_rounded, [Color(0xFF9D5CFF), Color(0xFFEC4899)]),
  GenericAvatarOption(Icons.pets_rounded, [Color(0xFF22D3EE), Color(0xFF4C8DFF)]),
  GenericAvatarOption(Icons.local_fire_department_rounded, [Color(0xFFEC4899), Color(0xFFF59E0B)]),
  GenericAvatarOption(Icons.eco_rounded, [Color(0xFF10D9A0), Color(0xFF4C8DFF)]),
  GenericAvatarOption(Icons.auto_awesome_rounded, [Color(0xFF9D5CFF), Color(0xFF22D3EE)]),
  GenericAvatarOption(Icons.terrain_rounded, [Color(0xFF4C8DFF), Color(0xFF10D9A0)]),
  GenericAvatarOption(Icons.diamond_rounded, [Color(0xFFEC4899), Color(0xFF9D5CFF)]),
];

const _genericAvatarScheme = 'generic-avatar://';

String genericAvatarUrlFor(int index) => '$_genericAvatarScheme$index';

bool isGenericAvatarUrl(String? url) =>
    url != null && url.startsWith(_genericAvatarScheme);

/// Returns null (falling back to whatever the caller does for "no avatar")
/// if the index is out of range — old data should never crash a render.
GenericAvatarOption? genericAvatarFromUrl(String url) {
  final index = int.tryParse(url.substring(_genericAvatarScheme.length));
  if (index == null || index < 0 || index >= genericAvatarCatalog.length) {
    return null;
  }
  return genericAvatarCatalog[index];
}

class GenericAvatar extends StatelessWidget {
  const GenericAvatar({super.key, required this.option, required this.radius});

  final GenericAvatarOption option;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: option.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(option.icon, color: Colors.white, size: radius * 0.95),
    );
  }
}
