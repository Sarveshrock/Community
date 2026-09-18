import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/generic_avatar.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/profile_providers.dart';
import '../widgets/add_experience_sheet.dart';
import '../widgets/add_proof_sheet.dart';
import '../widgets/avatar_picker_sheet.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _fullNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _companyController = TextEditingController();
  final _roleController = TextEditingController();
  final _bioController = TextEditingController();
  final _goalsController = TextEditingController();
  bool _initialized = false;
  bool _uploadingPhoto = false;

  bool _professionalDiscoverable = true;
  bool _localDiscoverable = false;
  bool _openToWork = false;
  bool _openToMentorship = false;

  void _hydrate(Profile? profile) {
    if (_initialized || profile == null) return;
    _fullNameController.text = profile.fullName ?? '';
    _cityController.text = profile.city ?? '';
    _companyController.text = profile.currentCompany ?? '';
    _roleController.text = profile.currentRole ?? '';
    _bioController.text = profile.bio ?? '';
    _goalsController.text = profile.careerGoals ?? '';
    _professionalDiscoverable = profile.professionalDiscoverable;
    _localDiscoverable = profile.localDiscoverable;
    _openToWork = profile.isOpenToWork;
    _openToMentorship = profile.isOpenToMentorship;
    _initialized = true;
  }

  Future<void> _pickAvatarSource() async {
    final action = await showAvatarSourceSheet(context);
    if (action == null || !mounted) return;
    switch (action) {
      case AvatarPickerAction.uploadPhoto:
        await _uploadPhoto();
      case AvatarPickerAction.chooseAvatar:
        await _chooseGenericAvatar();
      case AvatarPickerAction.removePhoto:
        await _removePhoto();
    }
  }

  Future<void> _uploadPhoto() async {
    final picker = ImagePicker();
    // No maxWidth here — full resolution feeds the cropper below so
    // zooming into a smaller region of the photo doesn't lose detail; the
    // cropper's own maxWidth/maxHeight constrain the final output instead.
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      maxWidth: 800,
      maxHeight: 800,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop photo',
          toolbarColor: HomeStyle.background,
          toolbarWidgetColor: Colors.white,
          backgroundColor: HomeStyle.background,
          activeControlsWidgetColor: HomeStyle.purple,
          dimmedLayerColor: Colors.black.withValues(alpha: 0.7),
          cropFrameColor: HomeStyle.purple,
          cropGridColor: Colors.white.withValues(alpha: 0.3),
          statusBarLight: false,
          cropStyle: CropStyle.circle,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop photo',
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );
    // Cancelled — the picked-but-uncropped original is never uploaded on
    // its own; cropping to a square is required, not optional, here.
    if (cropped == null || !mounted) return;

    final bytes = await cropped.readAsBytes();
    // compressFormat above is always jpg regardless of the source format.
    const ext = 'jpg';
    final repo = ref.read(profileRepositoryProvider);
    final user = ref.read(myProfileProvider).valueOrNull;
    if (user == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      // Previously unguarded: if the upload itself threw (e.g. a storage
      // bucket/policy missing on the linked project — see migration 0039),
      // nothing caught it, so the photo silently never appeared for anyone,
      // uploader included, with no error shown at all.
      // A bare storage path, not a public URL — the `avatars` bucket is
      // private (0049_profile_photo_privacy.sql); `UserAvatar` resolves a
      // signed URL from this on demand, respecting photo-visibility.
      final path = await repo.uploadAvatar(user.id, bytes, ext);
      if (!mounted) return;
      final success = await ref
          .read(profileControllerProvider.notifier)
          .updateProfile({'avatar_url': path});
      if (mounted && !success) {
        context.showSnack('Could not update photo', isError: true);
      }
    } catch (e) {
      if (mounted) context.showSnack('Could not upload photo: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _chooseGenericAvatar() async {
    final currentUrl = ref.read(myProfileProvider).valueOrNull?.avatarUrl;
    final currentIndex =
        isGenericAvatarUrl(currentUrl) ? genericAvatarFromUrl(currentUrl!) : null;
    final chosenIndex = await showAvatarGridSheet(
      context,
      currentIndex: currentIndex == null
          ? null
          : genericAvatarCatalog.indexOf(currentIndex),
    );
    if (chosenIndex == null || !mounted) return;
    final success = await ref
        .read(profileControllerProvider.notifier)
        .updateProfile({'avatar_url': genericAvatarUrlFor(chosenIndex)});
    if (mounted && !success) {
      context.showSnack('Could not update avatar', isError: true);
    }
  }

  Future<void> _removePhoto() async {
    final success = await ref
        .read(profileControllerProvider.notifier)
        .updateProfile({'avatar_url': null});
    if (mounted && !success) {
      context.showSnack('Could not remove photo', isError: true);
    }
  }

  Future<void> _save() async {
    final success =
        await ref.read(profileControllerProvider.notifier).updateProfile({
      'full_name': _fullNameController.text.trim(),
      'city': _cityController.text.trim(),
      'current_company': _companyController.text.trim().isEmpty
          ? null
          : _companyController.text.trim(),
      'current_role': _roleController.text.trim().isEmpty
          ? null
          : _roleController.text.trim(),
      'bio': _bioController.text.trim().isEmpty
          ? null
          : _bioController.text.trim(),
      'career_goals': _goalsController.text.trim().isEmpty
          ? null
          : _goalsController.text.trim(),
      'professional_discoverable': _professionalDiscoverable,
      'local_discoverable': _localDiscoverable,
      'is_open_to_work': _openToWork,
      'is_open_to_mentorship': _openToMentorship,
    });
    if (success && mounted) {
      context.showSnack('Profile updated');
    } else if (mounted) {
      context.showSnack('Could not update profile', isError: true);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _cityController.dispose();
    _companyController.dispose();
    _roleController.dispose();
    _bioController.dispose();
    _goalsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final isSaving = ref.watch(profileControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  _Header(isSaving: isSaving, onSave: _save),
                  Expanded(
                    child: profileAsync.when(
                      loading: () => const LoadingState(),
                      error: (e, _) => ErrorState(message: e.toString()),
                      data: (profile) {
                        _hydrate(profile);
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: GestureDetector(
                                  onTap:
                                      _uploadingPhoto ? null : _pickAvatarSource,
                                  child: Stack(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: HomeStyle.brandGradient,
                                          boxShadow: HomeStyle.glow(
                                              HomeStyle.purple,
                                              opacity: 0.3,
                                              blur: 16),
                                        ),
                                        child: UserAvatar(
                                            avatarUrl: profile?.avatarUrl,
                                            name: profile?.displayName ?? '?',
                                            radius: 48),
                                      ),
                                      if (_uploadingPhoto)
                                        Positioned.fill(
                                          child: CircleAvatar(
                                            radius: 51,
                                            backgroundColor: Colors.black
                                                .withValues(alpha: 0.45),
                                            child: const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: HomeStyle.brandGradient,
                                            border: Border.all(
                                                color: HomeStyle.background,
                                                width: 2.5),
                                          ),
                                          child: const Icon(Icons.camera_alt,
                                              size: 15, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              _LabeledField(
                                  label: 'Full name',
                                  controller: _fullNameController),
                              const SizedBox(height: 14),
                              _LabeledField(
                                  label: 'City', controller: _cityController),
                              const SizedBox(height: 14),
                              _LabeledField(
                                  label: 'Current role',
                                  controller: _roleController),
                              const SizedBox(height: 14),
                              _LabeledField(
                                  label: 'Current company',
                                  controller: _companyController),
                              const SizedBox(height: 14),
                              _LabeledField(
                                label: 'About',
                                controller: _bioController,
                                maxLines: 3,
                              ),
                              const SizedBox(height: 14),
                              _LabeledField(
                                label: 'Looking for / career goals',
                                controller: _goalsController,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 18),
                              _SwitchRow(
                                title: 'Discoverable in People',
                                value: _professionalDiscoverable,
                                onChanged: (v) => setState(
                                    () => _professionalDiscoverable = v),
                              ),
                              _SwitchRow(
                                title: 'Open to work',
                                value: _openToWork,
                                onChanged: (v) =>
                                    setState(() => _openToWork = v),
                              ),
                              _SwitchRow(
                                title: 'Open to mentoring others',
                                value: _openToMentorship,
                                onChanged: (v) =>
                                    setState(() => _openToMentorship = v),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.06)),
                              const SizedBox(height: 20),
                              _ExperienceSection(),
                              const SizedBox(height: 20),
                              Container(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.06)),
                              const SizedBox(height: 20),
                              _OptionalProofsSection(),
                            ],
                          ),
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
  const _Header({required this.isSaving, required this.onSave});

  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _IconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: () => context.pop(),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: HomeStyle.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: isSaving ? null : onSave,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  gradient: HomeStyle.brandGradient,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: HomeStyle.cardBase,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 21, color: HomeStyle.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: HomeStyle.textSecondary)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: HomeStyle.cardBase,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style:
                const TextStyle(color: HomeStyle.textPrimary, fontSize: 14.5),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: HomeStyle.textPrimary)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: HomeStyle.purple,
            inactiveThumbColor: HomeStyle.textSecondary,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
          ),
        ],
      ),
    );
  }
}

class _ExperienceSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experiencesAsync = ref.watch(myExperiencesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Experience',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: HomeStyle.textPrimary)),
            _AddButton(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: HomeStyle.cardBase,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const AddExperienceSheet(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        experiencesAsync.when(
          loading: () =>
              const LinearProgressIndicator(color: HomeStyle.purple),
          error: (_, __) => const Text('Could not load experience',
              style: TextStyle(color: HomeStyle.textSecondary)),
          data: (list) {
            if (list.isEmpty) {
              return const Text('No experience added yet',
                  style: TextStyle(
                      fontSize: 13, color: HomeStyle.textSecondary));
            }
            return Column(
              children: [
                for (final e in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _InfoRow(
                      title: '${e.role} · ${e.companyName}',
                      subtitle: e.employmentType.label,
                      onDelete: () => ref
                          .read(profileControllerProvider.notifier)
                          .deleteExperience(e.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OptionalProofsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proofsAsync = ref.watch(myOptionalProofsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Proof of Skills',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: HomeStyle.textPrimary)),
                Text('Optional',
                    style: TextStyle(
                        fontSize: 12, color: HomeStyle.textSecondary)),
              ],
            ),
            _AddButton(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: HomeStyle.cardBase,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const AddProofSheet(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        proofsAsync.when(
          loading: () =>
              const LinearProgressIndicator(color: HomeStyle.purple),
          error: (_, __) => const Text('Could not load proof links',
              style: TextStyle(color: HomeStyle.textSecondary)),
          data: (list) {
            if (list.isEmpty) {
              return const Text(
                'GitHub, LeetCode, Kaggle, Hugging Face, portfolio, certifications — entirely optional.',
                style: TextStyle(fontSize: 13, color: HomeStyle.textSecondary),
              );
            }
            return Column(
              children: [
                for (final p in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _InfoRow(
                      icon: Icons.link,
                      title: p.title?.isNotEmpty == true
                          ? p.title!
                          : p.proofType.label,
                      subtitle: p.url ?? '',
                      onDelete: () => ref
                          .read(profileControllerProvider.notifier)
                          .deleteOptionalProof(p.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeStyle.purple.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: HomeStyle.purple),
              SizedBox(width: 4),
              Text('Add',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: HomeStyle.purple)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    this.icon,
    required this.title,
    required this.subtitle,
    required this.onDelete,
  });

  final IconData? icon;
  final String title;
  final String subtitle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: HomeStyle.cardBase,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: HomeStyle.textSecondary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: HomeStyle.textPrimary)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: HomeStyle.textSecondary)),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 19, color: HomeStyle.pink),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
