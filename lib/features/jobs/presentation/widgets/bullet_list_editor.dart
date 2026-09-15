import 'package:flutter/material.dart';

import '../../../../core/widgets/form_section_card.dart';
import '../../../home/presentation/widgets/home_style.dart';

/// A small "+ Add" repeatable plain-text list editor — used for the Job
/// Builder's Responsibilities list. Each entry is just a string; order is
/// preserved as entered.
class BulletListEditor extends StatefulWidget {
  const BulletListEditor({
    super.key,
    required this.items,
    required this.onChanged,
    this.hint = 'Add an item',
  });

  final List<String> items;
  final ValueChanged<List<String>> onChanged;
  final String hint;

  @override
  State<BulletListEditor> createState() => _BulletListEditorState();
}

class _BulletListEditorState extends State<BulletListEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onChanged([...widget.items, text]);
    _controller.clear();
  }

  void _remove(int index) {
    final next = [...widget.items]..removeAt(index);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.circle, size: 6, color: HomeStyle.textSecondary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.items[i], style: const TextStyle(color: HomeStyle.textPrimary, height: 1.4)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: HomeStyle.textSecondary),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _remove(i),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: HomeStyle.textPrimary),
                decoration: darkInputDecoration(widget.hint),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ],
    );
  }
}
