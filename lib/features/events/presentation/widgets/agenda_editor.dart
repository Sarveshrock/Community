import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../home/presentation/widgets/home_style.dart';
import '../../domain/entities/event_agenda_item.dart';
import '../../../../core/widgets/form_section_card.dart';

/// The Agenda step's "+ Add session" list. Items are held as plain
/// `EventAgendaItem`s with placeholder id/eventId (real ones are assigned
/// server-side on create — `toInsertJson` never reads them back), so the
/// same entity is reused end to end instead of a parallel draft model.
class AgendaEditor extends StatelessWidget {
  const AgendaEditor({super.key, required this.items, required this.onChanged});

  final List<EventAgendaItem> items;
  final ValueChanged<List<EventAgendaItem>> onChanged;

  Future<void> _addItem(BuildContext context) async {
    final item = await showModalBottomSheet<EventAgendaItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeStyle.cardBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddAgendaItemSheet(),
    );
    if (item == null) return;
    onChanged([...items, item.copyWithOrder(items.length)]);
  }

  void _remove(int index) {
    final next = [...items]..removeAt(index);
    onChanged([for (var i = 0; i < next.length; i++) next[i].copyWithOrder(i)]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AgendaItemTile(item: items[i], onRemove: () => _remove(i)),
          ),
        OutlinedButton.icon(
          onPressed: () => _addItem(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add session'),
          style: OutlinedButton.styleFrom(
            foregroundColor: HomeStyle.purple,
            side: BorderSide(color: HomeStyle.purple.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }
}

extension on EventAgendaItem {
  EventAgendaItem copyWithOrder(int order) => EventAgendaItem(
        id: id,
        eventId: eventId,
        title: title,
        description: description,
        startsAt: startsAt,
        endsAt: endsAt,
        speakerProfileId: speakerProfileId,
        speakerName: speakerName,
        room: room,
        sortOrder: order,
      );
}

class _AgendaItemTile extends StatelessWidget {
  const _AgendaItemTile({required this.item, required this.onRemove});

  final EventAgendaItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(DateFormat.jm().format(item.startsAt),
                style: const TextStyle(fontSize: 12, color: HomeStyle.textSecondary)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                if (item.speakerDisplayName != null || item.room != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [item.speakerDisplayName, item.room].whereType<String>().join(' · '),
                    style: const TextStyle(fontSize: 12, color: HomeStyle.textSecondary),
                  ),
                ],
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

class _AddAgendaItemSheet extends StatefulWidget {
  const _AddAgendaItemSheet();

  @override
  State<_AddAgendaItemSheet> createState() => _AddAgendaItemSheetState();
}

class _AddAgendaItemSheetState extends State<_AddAgendaItemSheet> {
  final _titleController = TextEditingController();
  final _speakerController = TextEditingController();
  final _roomController = TextEditingController();
  TimeOfDay _start = TimeOfDay.now();
  TimeOfDay? _end;

  @override
  void dispose() {
    _titleController.dispose();
    _speakerController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _start : (_end ?? _start));
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) return;
    final now = DateTime.now();
    DateTime withTime(TimeOfDay t) => DateTime(now.year, now.month, now.day, t.hour, t.minute);
    Navigator.of(context).pop(EventAgendaItem(
      id: '',
      eventId: '',
      title: _titleController.text.trim(),
      startsAt: withTime(_start),
      endsAt: _end == null ? null : withTime(_end!),
      speakerName: _speakerController.text.trim().isEmpty ? null : _speakerController.text.trim(),
      room: _roomController.text.trim().isEmpty ? null : _roomController.text.trim(),
    ));
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
          const Text('Add session',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: HomeStyle.textPrimary),
            decoration: darkInputDecoration('Session title'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(isStart: true),
                  child: Text('Start: ${_start.format(context)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(isStart: false),
                  child: Text(_end == null ? 'End (optional)' : 'End: ${_end!.format(context)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _speakerController,
            style: const TextStyle(color: HomeStyle.textPrimary),
            decoration: darkInputDecoration('Speaker/host (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _roomController,
            style: const TextStyle(color: HomeStyle.textPrimary),
            decoration: darkInputDecoration('Room (optional)'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: const Text('Add session')),
          ),
        ],
      ),
    );
  }
}
