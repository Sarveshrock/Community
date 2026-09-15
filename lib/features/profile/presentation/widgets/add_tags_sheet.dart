import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../providers/profile_providers.dart';

/// The "+ Add skills" / "+ Add interests" quick-add sheet on the Profile
/// page. Reuses the exact catalog providers and `FilterChip` picking
/// pattern the onboarding flow already uses (`allSkillsProvider`/
/// `allInterestsProvider`), and writes through the existing
/// `setSkills`/`setInterests` repository calls via
/// [ProfileController.addSkillIds]/[addInterestIds] — this sheet adds no
/// new backend capability, only a second entry point to it outside
/// onboarding.
Future<void> showAddSkillsSheet(
  BuildContext context, {
  required Set<String> alreadySelected,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddTagsSheet<Skill>(
      title: 'Add skills',
      alreadySelected: alreadySelected,
      itemsProvider: allSkillsProvider,
      nameOf: (item) => item.name,
      idOf: (item) => item.id,
      onSave: (ref, ids) =>
          ref.read(profileControllerProvider.notifier).addSkillIds(ids),
    ),
  );
}

Future<void> showAddInterestsSheet(
  BuildContext context, {
  required Set<String> alreadySelected,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddTagsSheet<Interest>(
      title: 'Add interests',
      alreadySelected: alreadySelected,
      itemsProvider: allInterestsProvider,
      nameOf: (item) => item.name,
      idOf: (item) => item.id,
      onSave: (ref, ids) =>
          ref.read(profileControllerProvider.notifier).addInterestIds(ids),
    ),
  );
}

class _AddTagsSheet<T> extends ConsumerStatefulWidget {
  const _AddTagsSheet({
    super.key,
    required this.title,
    required this.alreadySelected,
    required this.itemsProvider,
    required this.nameOf,
    required this.idOf,
    required this.onSave,
  });

  final String title;
  final Set<String> alreadySelected;
  final ProviderListenable<AsyncValue<List<T>>> itemsProvider;
  final String Function(T item) nameOf;
  final String Function(T item) idOf;
  final Future<bool> Function(WidgetRef ref, List<String> ids) onSave;

  @override
  ConsumerState<_AddTagsSheet<T>> createState() => _AddTagsSheetState<T>();
}

class _AddTagsSheetState<T> extends ConsumerState<_AddTagsSheet<T>> {
  final _picked = <String>{};
  bool _saving = false;

  Future<void> _save() async {
    if (_picked.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    final success = await widget.onSave(ref, _picked.toList());
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      Navigator.of(context).pop();
    } else {
      context.showSnack('Could not save', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(widget.itemsProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title,
              style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
            child: SingleChildScrollView(
              child: itemsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator(),
                ),
                error: (_, __) => const Text('Could not load'),
                data: (items) {
                  final available = items
                      .where((item) => !widget.alreadySelected.contains(widget.idOf(item)))
                      .toList();
                  if (available.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('You\'ve already added everything available.'),
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in available)
                        FilterChip(
                          label: Text(widget.nameOf(item)),
                          selected: _picked.contains(widget.idOf(item)),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _picked.add(widget.idOf(item))
                                : _picked.remove(widget.idOf(item));
                          }),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_picked.isEmpty ? 'Close' : 'Add ${_picked.length}'),
            ),
          ),
        ],
      ),
    );
  }
}
