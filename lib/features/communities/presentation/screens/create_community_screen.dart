import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/multi_select_chips.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../profile/presentation/providers/profile_providers.dart' show allSkillsProvider;
import '../providers/community_providers.dart';
import '../widgets/community_detail_view.dart';

/// The Community Builder. A single scrollable, sectioned form mirroring the
/// Jobs/Events/Hackathon Team builder pattern, replacing the old
/// name/description/type-only form. Also doubles as Edit Community when
/// [editCommunityId] is set.
class CreateCommunityScreen extends ConsumerStatefulWidget {
  const CreateCommunityScreen({super.key, this.editCommunityId});

  final String? editCommunityId;

  @override
  ConsumerState<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends ConsumerState<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rulesController = TextEditingController();

  bool _initialized = false;
  bool _reviewing = false;
  bool _uploadingLogo = false;
  bool _uploadingCover = false;
  Uint8List? _logoBytes;
  String? _logoFileExt;
  String? _existingLogoUrl;
  Uint8List? _coverBytes;
  String? _coverFileExt;
  String? _existingCoverUrl;

  String _communityType = 'interest_based';
  final Set<String> _topics = {};
  final Set<String> _activities = {};
  final Set<String> _audience = {};
  String _accessType = 'public';

  bool get _isEditing => widget.editCommunityId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _descriptionController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  void _hydrate(Community community) {
    if (_initialized) return;
    _nameController.text = community.name;
    _taglineController.text = community.tagline ?? '';
    _descriptionController.text = community.description ?? '';
    _rulesController.text = community.rules ?? '';
    _communityType = community.communityType;
    _topics
      ..clear()
      ..addAll(community.topicNames);
    _activities
      ..clear()
      ..addAll(community.activities);
    _audience
      ..clear()
      ..addAll(community.audience);
    _accessType = community.accessType;
    _existingLogoUrl = community.logoUrl;
    _existingCoverUrl = community.coverImageUrl;
    _initialized = true;
  }

  String _slugify(String input) =>
      input.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 90);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _logoBytes = bytes;
      _logoFileExt = file.name.split('.').last;
    });
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _coverBytes = bytes;
      _coverFileExt = file.name.split('.').last;
    });
  }

  Map<String, dynamic> _buildData() {
    return {
      'name': _nameController.text.trim(),
      'tagline': _taglineController.text.trim().isEmpty ? null : _taglineController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      'community_type': _communityType,
      'activities': _activities.toList(),
      'audience': _audience.toList(),
      'rules': _rulesController.text.trim().isEmpty ? null : _rulesController.text.trim(),
      'access_type': _accessType,
      // Kept in sync with access_type so the existing is_private-keyed RLS
      // (community_members_select/community_posts_select/etc.) stays
      // correct — only 'private' hides a community from non-members.
      'is_private': _accessType == 'private',
    };
  }

  Community _previewCommunity() {
    return Community(
      id: widget.editCommunityId ?? 'preview',
      ownerId: '',
      name: _nameController.text.trim().isEmpty ? 'Untitled community' : _nameController.text.trim(),
      slug: 'preview',
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      coverImageUrl: _existingCoverUrl,
      communityType: _communityType,
      tagline: _taglineController.text.trim().isEmpty ? null : _taglineController.text.trim(),
      logoUrl: _existingLogoUrl,
      activities: _activities.toList(),
      audience: _audience.toList(),
      rules: _rulesController.text.trim().isEmpty ? null : _rulesController.text.trim(),
      accessType: _accessType,
      topicNames: _topics.toList(),
    );
  }

  bool _validate() {
    if (!_formKey.currentState!.validate()) return false;
    return true;
  }

  Future<void> _submit() async {
    final skills = ref.read(allSkillsProvider).valueOrNull ?? const [];
    final topicIds = [for (final s in skills) if (_topics.contains(s.name)) s.id];

    if (_isEditing) {
      final ok = await ref
          .read(communityControllerProvider.notifier)
          .updateCommunity(widget.editCommunityId!, _buildData(), topicSkillIds: topicIds);
      if (!mounted) return;
      if (!ok) {
        context.showSnack('Could not update community', isError: true);
        return;
      }
      if (_logoBytes != null && _logoFileExt != null) {
        final url = await ref
            .read(communityControllerProvider.notifier)
            .uploadLogo(widget.editCommunityId!, _logoBytes!, _logoFileExt!);
        if (url != null) {
          await ref
              .read(communityControllerProvider.notifier)
              .updateCommunity(widget.editCommunityId!, {'logo_url': url});
        }
      }
      if (_coverBytes != null && _coverFileExt != null) {
        final url = await ref
            .read(communityControllerProvider.notifier)
            .uploadCoverImage(widget.editCommunityId!, _coverBytes!, _coverFileExt!);
        if (url != null) {
          await ref
              .read(communityControllerProvider.notifier)
              .updateCommunity(widget.editCommunityId!, {'cover_image_url': url});
        }
      }
      if (mounted) {
        context.showSnack('Community updated');
        context.pop();
      }
      return;
    }

    final created = await ref.read(communityControllerProvider.notifier).createCommunity(
      {
        ..._buildData(),
        'slug': '${_slugify(_nameController.text)}-${DateTime.now().millisecondsSinceEpoch % 10000}',
      },
      topicSkillIds: topicIds,
    );
    if (!mounted) return;
    if (created == null) {
      context.showSnack('Could not create community', isError: true);
      return;
    }
    if (_logoBytes != null && _logoFileExt != null) {
      setState(() => _uploadingLogo = true);
      final url = await ref
          .read(communityControllerProvider.notifier)
          .uploadLogo(created.id, _logoBytes!, _logoFileExt!);
      if (url != null) {
        await ref.read(communityControllerProvider.notifier).updateCommunity(created.id, {'logo_url': url});
      }
      if (mounted) setState(() => _uploadingLogo = false);
    }
    if (_coverBytes != null && _coverFileExt != null) {
      setState(() => _uploadingCover = true);
      final url = await ref
          .read(communityControllerProvider.notifier)
          .uploadCoverImage(created.id, _coverBytes!, _coverFileExt!);
      if (url != null) {
        await ref.read(communityControllerProvider.notifier).updateCommunity(created.id, {'cover_image_url': url});
      }
      if (mounted) setState(() => _uploadingCover = false);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      final communityAsync = ref.watch(communityDetailProvider(widget.editCommunityId!));
      if (communityAsync.isLoading) {
        return const Scaffold(backgroundColor: HomeStyle.background, body: LoadingState());
      }
      if (communityAsync.hasError) {
        return Scaffold(backgroundColor: HomeStyle.background, body: ErrorState(message: communityAsync.error.toString()));
      }
      _hydrate(communityAsync.value!);
    }
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) {
    final isSaving = ref.watch(communityControllerProvider).isLoading || _uploadingLogo || _uploadingCover;
    final skillsAsync = ref.watch(allSkillsProvider);

    if (_reviewing) {
      return Scaffold(
        backgroundColor: HomeStyle.background,
        appBar: AppBar(
          backgroundColor: HomeStyle.background,
          title: const Text('Preview', style: TextStyle(color: HomeStyle.textPrimary)),
          iconTheme: const IconThemeData(color: HomeStyle.textPrimary),
        ),
        body: ResponsiveCenter(
          child: Column(
            children: [
              Expanded(
                child: CommunityDetailView(
                  community: _previewCommunity(),
                  logoBytesPreview: _logoBytes != null ? MemoryImage(_logoBytes!) : null,
                  coverBytesPreview: _coverBytes != null ? MemoryImage(_coverBytes!) : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: () => setState(() => _reviewing = false), child: const Text('Back to edit')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: isSaving ? null : _submit,
                          child: isSaving
                              ? const SizedBox(
                                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_isEditing ? 'Save changes' : 'Create Community'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: HomeStyle.background,
        title: Text(_isEditing ? 'Edit Community' : 'New Community', style: const TextStyle(color: HomeStyle.textPrimary)),
        iconTheme: const IconThemeData(color: HomeStyle.textPrimary),
        actions: [
          TextButton(
            onPressed: () {
              if (_validate()) setState(() => _reviewing = true);
            },
            child: const Text('Preview'),
          ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 560,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FormSectionCard(
                  icon: Icons.info_outline_rounded,
                  title: 'Basic information',
                  children: [
                    Row(
                      children: [
                        _ImagePickerBox(
                          bytes: _logoBytes,
                          existingUrl: _existingLogoUrl,
                          label: 'Logo',
                          size: 76,
                          shape: BoxShape.circle,
                          onTap: _pickLogo,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ImagePickerBox(
                            bytes: _coverBytes,
                            existingUrl: _existingCoverUrl,
                            label: 'Cover image',
                            size: 76,
                            shape: BoxShape.rectangle,
                            onTap: _pickCover,
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Community name'),
                      validator: (v) => Validators.required(v, fieldName: 'Name'),
                    ),
                    TextFormField(
                      controller: _taglineController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Tagline (optional)',
                          hint: 'e.g. Learn, build and grow with Java developers.'),
                    ),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('What is this community about?'),
                    ),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _communityType,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Community type'),
                      items: [for (final t in kCommunityTypes) DropdownMenuItem(value: t, child: Text(communityTypeLabel(t)))],
                      onChanged: (v) => setState(() => _communityType = v ?? _communityType),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.sell_outlined,
                  title: 'Topics & tags',
                  children: [
                    skillsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Could not load topics'),
                      data: (skills) => MultiSelectChips(
                        options: {...skills.map((s) => s.name), ..._topics}.toList(),
                        selected: _topics,
                        onChanged: (v) => setState(() {
                          _topics
                            ..clear()
                            ..addAll(v);
                        }),
                      ),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.groups_2_outlined,
                  title: 'What can members do here?',
                  children: [
                    MultiSelectChips(
                      options: kCommunityActivities,
                      selected: _activities,
                      onChanged: (v) => setState(() {
                        _activities
                          ..clear()
                          ..addAll(v);
                      }),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.person_search_outlined,
                  title: 'Who is this community for?',
                  children: [
                    MultiSelectChips(
                      options: kCommunityAudiences,
                      selected: _audience,
                      onChanged: (v) => setState(() {
                        _audience
                          ..clear()
                          ..addAll(v);
                      }),
                    ),
                  ],
                ),
                CollapsibleFormSection(
                  icon: Icons.gavel_outlined,
                  title: 'Community rules',
                  subtitle: 'Optional — shown to everyone before they join',
                  children: [
                    TextFormField(
                      controller: _rulesController,
                      maxLines: 5,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Rules', hint: '1. Be respectful\n2. No spam\n3. Keep it relevant'),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.visibility_outlined,
                  title: 'Privacy & access',
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _accessType,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Who can join?'),
                      items: [
                        for (final a in kCommunityAccessTypes) DropdownMenuItem(value: a, child: Text(communityAccessTypeLabel(a))),
                      ],
                      onChanged: (v) => setState(() => _accessType = v ?? _accessType),
                    ),
                    Text(
                      switch (_accessType) {
                        'request_to_join' => 'Anyone can discover this community, but joining requires your approval.',
                        'private' => 'Not publicly discoverable — visible only to members and you.',
                        _ => 'Anyone can discover and join instantly.',
                      },
                      style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: isSaving
                          ? null
                          : () {
                              if (_validate()) setState(() => _reviewing = true);
                            },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: HomeStyle.brandGradient,
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: HomeStyle.glow(HomeStyle.purple, opacity: 0.3),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Preview',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePickerBox extends StatelessWidget {
  const _ImagePickerBox({
    required this.bytes,
    required this.existingUrl,
    required this.label,
    required this.size,
    required this.shape,
    required this.onTap,
  });

  final Uint8List? bytes;
  final String? existingUrl;
  final String label;
  final double size;
  final BoxShape shape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = bytes != null || existingUrl != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: size,
        width: shape == BoxShape.circle ? size : double.infinity,
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(16) : null,
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          image: bytes != null
              ? DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover)
              : existingUrl != null
                  ? DecorationImage(image: NetworkImage(existingUrl!), fit: BoxFit.cover)
                  : null,
        ),
        child: hasImage
            ? null
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined, color: HomeStyle.textSecondary, size: 22),
                    Text(label, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 10.5)),
                  ],
                ),
              ),
      ),
    );
  }
}
