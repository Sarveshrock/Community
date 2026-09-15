import 'package:flutter/material.dart';

import '../../features/home/presentation/widgets/home_style.dart';

/// A row of toggleable chips over a fixed set of options — reused across
/// builder forms (Events' audience/what-to-bring/benefits, Jobs' required/
/// nice-to-have skills and benefits, ...): "make these configurable
/// instead of forcing the user to type everything out".
class MultiSelectChips extends StatelessWidget {
  const MultiSelectChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _Chip(
            label: option,
            isSelected: selected.contains(option),
            onTap: () {
              final next = {...selected};
              selected.contains(option) ? next.remove(option) : next.add(option);
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected ? HomeStyle.brandGradient : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(100),
            border: isSelected ? null : Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : HomeStyle.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
