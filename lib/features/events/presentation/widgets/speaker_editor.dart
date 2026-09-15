import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/widgets/home_style.dart';
import '../../../people/presentation/providers/people_providers.dart';
import '../../domain/entities/event_speaker.dart';
import '../../../../core/widgets/form_section_card.dart';

/// The Speakers/Hosts step's "+ Add speaker" list. Searches real Communeo
/// profiles (reusing `PeopleRepository.search` — the same lookup People
/// uses) so a linked speaker is never a duplicate person record; "not on
/// Communeo" falls back to free-text name/role/company/bio.
class SpeakerEditor extends StatelessWidget {
  const SpeakerEditor({super.key, required this.speakers, required this.onChanged});

  final List<EventSpeaker> speakers;
  final ValueChanged<List<EventSpeaker>> onChanged;

  Future<void> _addSpeaker(BuildContext context) async {
    final speaker = await showModalBottomSheet<EventSpeaker>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeStyle.cardBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddSpeakerSheet(),
    );
    if (speaker == null) return;
    onChanged([...speakers, speaker.copyWithOrder(speakers.length)]);
  }

  void _remove(int index) {
    final next = [...speakers]..removeAt(index);
    onChanged([for (var i = 0; i < next.length; i++) next[i].copyWithOrder(i)]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < speakers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SpeakerTile(speaker: speakers[i], onRemove: () => _remove(i)),
          ),
        OutlinedButton.icon(
          onPressed: () => _addSpeaker(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add speaker'),
          style: OutlinedButton.styleFrom(
            foregroundColor: HomeStyle.purple,
            side: BorderSide(color: HomeStyle.purple.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }
}

extension on EventSpeaker {
  EventSpeaker copyWithOrder(int order) => EventSpeaker(
        id: id,
        eventId: eventId,
        profileId: profileId,
        profileName: profileName,
        profileAvatarUrl: profileAvatarUrl,
        name: name,
        role: role,
        company: company,
        bio: bio,
        sortOrder: order,
      );
}

class _SpeakerTile extends StatelessWidget {
  const _SpeakerTile({required this.speaker, required this.onRemove});

  final EventSpeaker speaker;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final subtitle = [speaker.role, speaker.company].whereType<String>().join(' · ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: HomeStyle.purple.withValues(alpha: 0.25),
            child: Text(speaker.displayName.isEmpty ? '?' : speaker.displayName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(speaker.displayName,
                    style: const TextStyle(
                        color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: HomeStyle.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: HomeStyle.textSecondary),
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AddSpeakerSheet extends ConsumerStatefulWidget {
  const _AddSpeakerSheet();

  @override
  ConsumerState<_AddSpeakerSheet> createState() => _AddSpeakerSheetState();
}

class _AddSpeakerSheetState extends ConsumerState<_AddSpeakerSheet> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _companyController = TextEditingController();
  bool _manualEntry = false;
  List<Profile>? _results;
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _roleController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = null);
      return;
    }
    setState(() => _searching = true);
    final profiles = await ref
        .read(peopleRepositoryProvider)
        .search(PeopleFilters(query: query.trim()), limit: 8);
    if (!mounted) return;
    setState(() {
      _results = profiles;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          const Text('Add speaker',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
          const SizedBox(height: 16),
          if (!_manualEntry) ...[
            TextField(
              controller: _searchController,
              style: const TextStyle(color: HomeStyle.textPrimary),
              decoration: darkInputDecoration('Search Communeo profiles',
                  hint: 'Search by name', suffixIcon: const Icon(Icons.search_rounded)),
              onChanged: _search,
            ),
            const SizedBox(height: 10),
            if (_searching) const LinearProgressIndicator(),
            if (_results != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final profile in _results!)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                          title: Text(profile.displayName,
                              style: const TextStyle(color: HomeStyle.textPrimary)),
                          subtitle: Text(profile.headline,
                              style: const TextStyle(color: HomeStyle.textSecondary)),
                          onTap: () => Navigator.of(context).pop(EventSpeaker(
                            id: '',
                            eventId: '',
                            profileId: profile.id,
                            profileName: profile.displayName,
                            profileAvatarUrl: profile.avatarUrl,
                            role: profile.currentRole ?? '',
                            company: profile.currentCompany ?? '',
                          )),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _manualEntry = true),
              child: const Text('Not on Communeo? Add manually'),
            ),
          ] else ...[
            TextField(
              controller: _nameController,
              style: const TextStyle(color: HomeStyle.textPrimary),
              decoration: darkInputDecoration('Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roleController,
              style: const TextStyle(color: HomeStyle.textPrimary),
              decoration: darkInputDecoration('Role (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _companyController,
              style: const TextStyle(color: HomeStyle.textPrimary),
              decoration: darkInputDecoration('Company (optional)'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_nameController.text.trim().isEmpty) return;
                  Navigator.of(context).pop(EventSpeaker(
                    id: '',
                    eventId: '',
                    name: _nameController.text.trim(),
                    role: _roleController.text.trim().isEmpty ? null : _roleController.text.trim(),
                    company:
                        _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
                  ));
                },
                child: const Text('Add speaker'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
