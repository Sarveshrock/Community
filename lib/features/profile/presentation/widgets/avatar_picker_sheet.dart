import 'package:flutter/material.dart';

import '../../../../core/widgets/generic_avatar.dart';

enum AvatarPickerAction { uploadPhoto, chooseAvatar, removePhoto }

/// The entry sheet from tapping a profile photo: upload a real photo, pick
/// one of the built-in illustrated avatars instead, or remove the current
/// photo. Returned value tells the caller what to do next — this widget
/// itself performs no upload/save, keeping that logic where it already
/// lives in [EditProfileScreen].
Future<AvatarPickerAction?> showAvatarSourceSheet(BuildContext context) {
  return showModalBottomSheet<AvatarPickerAction>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile photo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Use a real photo, or pick an avatar if you\'d rather not.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Upload a photo'),
              onTap: () =>
                  Navigator.of(context).pop(AvatarPickerAction.uploadPhoto),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.face_retouching_natural_outlined),
              title: const Text('Choose an avatar'),
              subtitle: const Text('No photo needed'),
              onTap: () =>
                  Navigator.of(context).pop(AvatarPickerAction.chooseAvatar),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Remove photo',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () =>
                  Navigator.of(context).pop(AvatarPickerAction.removePhoto),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A grid of the built-in illustrated avatars — returns the chosen index,
/// or null if dismissed without choosing.
Future<int?> showAvatarGridSheet(BuildContext context, {int? currentIndex}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose an avatar', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
              ),
              itemCount: genericAvatarCatalog.length,
              itemBuilder: (context, i) {
                final selected = i == currentIndex;
                return InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap: () => Navigator.of(context).pop(i),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2.5)
                          : null,
                    ),
                    child: GenericAvatar(
                        option: genericAvatarCatalog[i], radius: 32),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
