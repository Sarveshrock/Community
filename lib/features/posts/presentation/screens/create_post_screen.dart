import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../people/presentation/providers/people_providers.dart';
import '../providers/post_providers.dart';

const _maxMediaBytes = 25 * 1024 * 1024; // 25 MB, matches chat attachments
const _maxMediaItems = 6;
final _urlPattern = RegExp(r'https?://[^\s]+');

class _PendingMedia {
  _PendingMedia(
      {required this.bytes, required this.fileName, required this.type});
  final Uint8List bytes;
  final String fileName;
  final PostMediaType type;
}

class _MentionedPerson {
  const _MentionedPerson({required this.id, required this.name});
  final String id;
  final String name;
}

/// The **one** post composer, pushed identically from Home, Profile, and
/// the Create tab (spec: "Do not create three separate implementations").
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _pendingMedia = <_PendingMedia>[];
  final _mentioned = <_MentionedPerson>[];
  String? _category;
  bool _publishing = false;

  List<String> get _detectedLinks => _urlPattern
      .allMatches(_contentController.text)
      .map((m) => m.group(0)!)
      .toSet()
      .toList();

  bool get _canPublish =>
      !_publishing &&
      (_contentController.text.trim().isNotEmpty ||
          _pendingMedia.isNotEmpty ||
          _detectedLinks.isNotEmpty);

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_pendingMedia.length >= _maxMediaItems) return;
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    for (final file in picked.take(_maxMediaItems - _pendingMedia.length)) {
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxMediaBytes) continue;
      setState(() => _pendingMedia.add(_PendingMedia(
          bytes: bytes, fileName: file.name, type: PostMediaType.image)));
    }
  }

  Future<void> _pickVideo() async {
    if (_pendingMedia.length >= _maxMediaItems) return;
    final result = await FilePicker.platform
        .pickFiles(type: FileType.video, withData: true);
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    if (bytes.length > _maxMediaBytes) {
      if (mounted) {
        context.showSnack('That video is too large (25 MB max)', isError: true);
      }
      return;
    }
    setState(() => _pendingMedia.add(_PendingMedia(
        bytes: bytes, fileName: file.name, type: PostMediaType.video)));
  }

  void _removeMedia(_PendingMedia media) =>
      setState(() => _pendingMedia.remove(media));

  Future<void> _openMentionPicker() async {
    final picked = await showModalBottomSheet<_MentionedPerson>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeStyle.background,
      builder: (_) => const _MentionPickerSheet(),
    );
    if (picked == null || _mentioned.any((m) => m.id == picked.id)) return;
    setState(() {
      _mentioned.add(picked);
      final text = _contentController.text;
      final newText = text.endsWith('@')
          ? '${text.substring(0, text.length - 1)}@${picked.name} '
          : '$text@${picked.name} ';
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    });
  }

  Future<void> _publish() async {
    if (!_canPublish) return;
    setState(() => _publishing = true);

    final controller = ref.read(postControllerProvider.notifier);
    final mediaItems = <(String, PostMediaType)>[];
    for (final pending in _pendingMedia) {
      final path = await controller.uploadMedia(
          bytes: pending.bytes, fileName: pending.fileName);
      if (path == null) {
        if (mounted) {
          setState(() => _publishing = false);
          context.showSnack('Could not upload ${pending.fileName}',
              isError: true);
        }
        return;
      }
      mediaItems.add((path, pending.type));
    }

    final ok = await controller.createPost(
      content: _contentController.text.trim().isEmpty
          ? null
          : _contentController.text.trim(),
      category: _category,
      mediaItems: mediaItems,
      linkUrls: _detectedLinks,
      mentionedProfileIds: _mentioned.map((m) => m.id).toList(),
    );

    if (!mounted) return;
    setState(() => _publishing = false);
    if (ok) {
      context.showSnack('Post published');
      context.pop();
    } else {
      context.showSnack('Could not publish post', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: Column(
              children: [
                _Header(canPublish: _canPublish, publishing: _publishing, onPublish: _publish),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: HomeStyle.cardBase,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: TextField(
                            controller: _contentController,
                            autofocus: true,
                            maxLines: null,
                            minLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(
                                color: HomeStyle.textPrimary, fontSize: 14.5),
                            decoration: const InputDecoration(
                              hintText:
                                  "What's on your mind? Share something about tech, code, or your latest project…",
                              hintStyle:
                                  TextStyle(color: HomeStyle.textSecondary),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(14),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_detectedLinks.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final url in _detectedLinks)
                                HomeChip(Uri.tryParse(url)?.host ?? url,
                                    accent: HomeStyle.blue),
                            ],
                          ),
                        ],
                        if (_mentioned.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final m in _mentioned)
                                _RemovableChip(
                                  label: m.name,
                                  onRemove: () =>
                                      setState(() => _mentioned.remove(m)),
                                ),
                            ],
                          ),
                        ],
                        if (_pendingMedia.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final media in _pendingMedia)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: media.type == PostMediaType.image
                                          ? Image.memory(media.bytes,
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover)
                                          : Container(
                                              width: 100,
                                              height: 100,
                                              color: Colors.black87,
                                              alignment: Alignment.center,
                                              child: Column(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.videocam,
                                                      color: Colors.white),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 4),
                                                    child: Text(
                                                      media.fileName,
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () => _removeMedia(media),
                                        child: const CircleAvatar(
                                          radius: 11,
                                          backgroundColor: Colors.black54,
                                          child: Icon(Icons.close,
                                              size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.06)),
                        const SizedBox(height: 16),
                        const Text('Category (optional)',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: HomeStyle.textSecondary)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in kPostCategories)
                              _CategoryChoiceChip(
                                label: c,
                                selected: _category == c,
                                onTap: () => setState(
                                    () => _category = _category == c ? null : c),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.06)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _ComposerAction(
                              icon: Icons.image_outlined,
                              label: 'Image',
                              onTap: _pendingMedia.length >= _maxMediaItems
                                  ? null
                                  : _pickImages,
                            ),
                            const SizedBox(width: 8),
                            _ComposerAction(
                              icon: Icons.videocam_outlined,
                              label: 'Video',
                              onTap: _pendingMedia.length >= _maxMediaItems
                                  ? null
                                  : _pickVideo,
                            ),
                            const SizedBox(width: 8),
                            _ComposerAction(
                              icon: Icons.alternate_email,
                              label: 'Mention',
                              onTap: _openMentionPicker,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.canPublish, required this.publishing, required this.onPublish});

  final bool canPublish;
  final bool publishing;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _IconButton(
              icon: Icons.close_rounded,
              tooltip: 'Cancel',
              onTap: () => context.pop()),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Create post',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary)),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: canPublish ? onPublish : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  gradient: canPublish ? HomeStyle.brandGradient : null,
                  color: canPublish ? null : HomeStyle.cardBase,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: publishing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Publish',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: canPublish
                                ? Colors.white
                                : HomeStyle.textSecondary)),
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

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 6, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: HomeStyle.purple.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: HomeStyle.purple.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.alternate_email, size: 12, color: HomeStyle.purple),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HomeStyle.purple)),
          InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 13, color: HomeStyle.purple),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChoiceChip extends StatelessWidget {
  const _CategoryChoiceChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: selected ? HomeStyle.brandGradient : null,
            color: selected ? null : HomeStyle.cardBase,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
                color: selected
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.10)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : HomeStyle.textSecondary)),
        ),
      ),
    );
  }
}

class _ComposerAction extends StatelessWidget {
  const _ComposerAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: HomeStyle.cardBase,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 17,
                  color: enabled
                      ? HomeStyle.textSecondary
                      : HomeStyle.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? HomeStyle.textSecondary
                          : HomeStyle.textSecondary.withValues(alpha: 0.4))),
            ],
          ),
        ),
      ),
    );
  }
}

class _MentionPickerSheet extends ConsumerStatefulWidget {
  const _MentionPickerSheet();

  @override
  ConsumerState<_MentionPickerSheet> createState() =>
      _MentionPickerSheetState();
}

class _MentionPickerSheetState extends ConsumerState<_MentionPickerSheet> {
  @override
  void dispose() {
    Future.microtask(() =>
        ref.read(peopleFiltersProvider.notifier).state = const PeopleFilters());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(peopleSearchResultsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mention someone',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: HomeStyle.textPrimary)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: HomeStyle.cardBase,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                autofocus: true,
                style: const TextStyle(color: HomeStyle.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search by name',
                  hintStyle: TextStyle(color: HomeStyle.textSecondary),
                  prefixIcon: Icon(Icons.search, color: HomeStyle.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (value) =>
                    ref.read(peopleFiltersProvider.notifier).state =
                        PeopleFilters(
                            query: value.trim().isEmpty ? null : value.trim()),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: resultsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: HomeStyle.purple)),
                error: (e, _) => Center(
                    child: Text(e.toString(),
                        style:
                            const TextStyle(color: HomeStyle.textSecondary))),
                data: (people) => ListView.builder(
                  controller: scrollController,
                  itemCount: people.length,
                  itemBuilder: (context, i) {
                    final p = people[i];
                    return ListTile(
                      leading: UserAvatar(
                          avatarUrl: p.avatarUrl,
                          name: p.displayName,
                          radius: 20),
                      title: Text(p.displayName,
                          style: const TextStyle(color: HomeStyle.textPrimary)),
                      subtitle: Text(p.headline,
                          style:
                              const TextStyle(color: HomeStyle.textSecondary)),
                      onTap: () => Navigator.of(context)
                          .pop(_MentionedPerson(id: p.id, name: p.displayName)),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
