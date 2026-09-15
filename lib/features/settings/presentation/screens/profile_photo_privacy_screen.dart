import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// Settings > Privacy > Profile Photo. Writes straight through the existing
/// `profiles.photo_visibility` column via [ProfileController.updateProfile]
/// — the same generic patch method every other profile setting already
/// uses — so there's no parallel settings system for this one preference.
///
/// The actual enforcement of whatever is picked here happens server-side,
/// in `can_view_profile_photo()` / the `avatars` bucket's Storage RLS policy
/// (0049_profile_photo_privacy.sql), and is applied everywhere through
/// `UserAvatar`. This screen only ever writes the setting; it never decides
/// who can see anyone's photo.
class ProfilePhotoPrivacyScreen extends ConsumerWidget {
  const ProfilePhotoPrivacyScreen({super.key});

  Future<void> _select(BuildContext context, WidgetRef ref, ProfilePhotoVisibility value) async {
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .updateProfile({'photo_visibility': value.value});
    if (context.mounted && !ok) {
      context.showSnack('Could not update your photo privacy setting', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    final current = profileAsync.valueOrNull?.photoVisibility ?? ProfilePhotoVisibility.everyone;
    final isSaving = ref.watch(profileControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              maxWidth: 480,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                      child: Row(
                        children: [
                          _BackButton(onTap: () => context.pop()),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Profile Photo',
                                    style: TextStyle(
                                        fontSize: 22, fontWeight: FontWeight.w800, color: HomeStyle.textPrimary)),
                                SizedBox(height: 2),
                                Text('Choose who can see your profile photo.',
                                    style: TextStyle(fontSize: 12.5, color: HomeStyle.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: HomeStyle.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: const Text(
                        'Your profile photo may appear in different parts of Communeo. '
                        'This setting controls who can see the actual photo — everyone else '
                        'sees a neutral avatar instead.',
                        style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 18),
                    GradientBorderCard(
                      radius: 20,
                      gradient: LinearGradient(
                          colors: [HomeStyle.purple.withValues(alpha: 0.20), HomeStyle.blue.withValues(alpha: 0.10)]),
                      child: Column(
                        children: [
                          for (final option in ProfilePhotoVisibility.values)
                            _VisibilityOption(
                              option: option,
                              selected: option == current,
                              enabled: !isSaving,
                              isLast: option == ProfilePhotoVisibility.values.last,
                              onTap: () => _select(context, ref, option),
                            ),
                        ],
                      ),
                    ),
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

class _VisibilityOption extends StatelessWidget {
  const _VisibilityOption({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.isLast,
    required this.onTap,
  });

  final ProfilePhotoVisibility option;
  final bool selected;
  final bool enabled;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? HomeStyle.purple : HomeStyle.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.label,
                        style: TextStyle(
                            color: selected ? HomeStyle.textPrimary : HomeStyle.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(option.description,
                        style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5, height: 1.3)),
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: HomeStyle.cardBase,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: const Icon(Icons.arrow_back_rounded, size: 21, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
