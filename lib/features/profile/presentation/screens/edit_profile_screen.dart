import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/generic_avatar.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
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
    final file = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.split('.').last;
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
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: isSaving ? null : _save,
            child: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (profile) {
          _hydrate(profile);
          return ResponsiveCenter(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _uploadingPhoto ? null : _pickAvatarSource,
                      child: Stack(
                        children: [
                          UserAvatar(
                              avatarUrl: profile?.avatarUrl,
                              name: profile?.displayName ?? '?',
                              radius: 48),
                          if (_uploadingPhoto)
                            Positioned.fill(
                              child: CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.black.withValues(alpha: 0.45),
                                child: const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white),
                                ),
                              ),
                            ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: context.colors.primary,
                              child: const Icon(Icons.camera_alt,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                      controller: _fullNameController,
                      decoration:
                          const InputDecoration(labelText: 'Full name')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'City')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _roleController,
                      decoration:
                          const InputDecoration(labelText: 'Current role')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _companyController,
                      decoration:
                          const InputDecoration(labelText: 'Current company')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'About', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _goalsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Looking for / career goals',
                        alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Discoverable in People'),
                    value: _professionalDiscoverable,
                    onChanged: (v) =>
                        setState(() => _professionalDiscoverable = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Open to work'),
                    value: _openToWork,
                    onChanged: (v) => setState(() => _openToWork = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Open to mentoring others'),
                    value: _openToMentorship,
                    onChanged: (v) => setState(() => _openToMentorship = v),
                  ),
                  const Divider(height: 32),
                  _ExperienceSection(),
                  const Divider(height: 32),
                  _OptionalProofsSection(),
                ],
              ),
            ),
          );
        },
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
            Text('Experience',
                style: context.textStyles.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const AddExperienceSheet(),
              ),
            ),
          ],
        ),
        experiencesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('Could not load experience'),
          data: (list) {
            if (list.isEmpty) {
              return Text('No experience added yet',
                  style: TextStyle(color: context.colors.onSurfaceVariant));
            }
            return Column(
              children: [
                for (final e in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${e.role} · ${e.companyName}'),
                    subtitle: Text(e.employmentType.label),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Proof of Skills',
                    style: context.textStyles.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text('Optional',
                    style: context.textStyles.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant)),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const AddProofSheet(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        proofsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('Could not load proof links'),
          data: (list) {
            if (list.isEmpty) {
              return Text(
                'GitHub, LeetCode, Kaggle, Hugging Face, portfolio, certifications — entirely optional.',
                style: TextStyle(color: context.colors.onSurfaceVariant),
              );
            }
            return Column(
              children: [
                for (final p in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link),
                    title: Text(p.title?.isNotEmpty == true
                        ? p.title!
                        : p.proofType.label),
                    subtitle: Text(p.url ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
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
