import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/user_avatar.dart';
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
      if (mounted)
        context.showSnack('That video is too large (25 MB max)', isError: true);
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
      appBar: AppBar(
        title: const Text('Create post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: FilledButton(
                onPressed: _canPublish ? _publish : null,
                child: _publishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Publish'),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _contentController,
              autofocus: true,
              maxLines: null,
              minLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    "What's on your mind? Share something about tech, code, or your latest project…",
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_detectedLinks.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final url in _detectedLinks)
                Chip(
                  avatar: const Icon(Icons.link, size: 16),
                  label: Text(Uri.tryParse(url)?.host ?? url,
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            if (_mentioned.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final m in _mentioned)
                    Chip(
                      avatar: const Icon(Icons.alternate_email, size: 14),
                      label: Text(m.name),
                      onDeleted: () => setState(() => _mentioned.remove(m)),
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
                                  width: 100, height: 100, fit: BoxFit.cover)
                              : Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.black87,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.videocam,
                                          color: Colors.white),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: Text(
                                          media.fileName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('Category (optional)',
                style: context.textStyles.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in kPostCategories)
                  ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (selected) =>
                        setState(() => _category = selected ? c : null),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Image'),
                  onPressed: _pendingMedia.length >= _maxMediaItems
                      ? null
                      : _pickImages,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Video'),
                  onPressed: _pendingMedia.length >= _maxMediaItems
                      ? null
                      : _pickVideo,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.alternate_email),
                  label: const Text('Mention'),
                  onPressed: _openMentionPicker,
                ),
              ],
            ),
          ],
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
            Text('Mention someone',
                style: context.textStyles.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'Search by name', prefixIcon: Icon(Icons.search)),
              onChanged: (value) =>
                  ref.read(peopleFiltersProvider.notifier).state =
                      PeopleFilters(
                          query: value.trim().isEmpty ? null : value.trim()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: resultsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
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
                      title: Text(p.displayName),
                      subtitle: Text(p.headline),
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
