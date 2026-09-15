import 'package:flutter/material.dart';

import '../../features/home/presentation/widgets/home_style.dart';

/// Shared dark-input styling for a "premium dark" sectioned builder form
/// (Events' Event Builder, Jobs' Job Builder, ...) — one definition so
/// every field looks consistent without repeating this decoration by hand
/// at each call site.
InputDecoration darkInputDecoration(String label, {String? hint, Widget? suffixIcon}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffixIcon,
    labelStyle: const TextStyle(color: HomeStyle.textSecondary),
    hintStyle: TextStyle(color: HomeStyle.textSecondary.withValues(alpha: 0.6)),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.04),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: HomeStyle.purple, width: 1.4),
    ),
  );
}

/// A titled, always-visible section of a builder form — one rounded card
/// per step, so the user always sees "what am I filling in right now".
class FormSectionCard extends StatelessWidget {
  const FormSectionCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // A Material (not a plain color-decorated Container) so any
      // ListTile/SwitchListTile/InkWell inside this section has a proper
      // ink surface right where its background actually is — otherwise
      // Flutter paints the ripple on the Scaffold's Material underneath
      // this section's own opaque background, where it's invisible.
      child: Material(
        color: HomeStyle.cardBase.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: HomeStyle.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: const TextStyle(fontSize: 12, color: HomeStyle.textSecondary)),
              ],
              const SizedBox(height: 14),
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A collapsed-by-default section for the less commonly needed fields in a
/// builder form — "use expandable areas... do not overwhelm the user".
class CollapsibleFormSection extends StatefulWidget {
  const CollapsibleFormSection({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  State<CollapsibleFormSection> createState() => _CollapsibleFormSectionState();
}

class _CollapsibleFormSectionState extends State<CollapsibleFormSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // Material (not a color-decorated Container) for the same reason as
      // FormSectionCard — the header's InkWell and any SwitchListTile in
      // the expanded content need a real ink surface at their own
      // background, not the Scaffold's Material underneath this opaque one.
      child: Material(
        color: HomeStyle.cardBase.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(widget.icon, size: 18, color: HomeStyle.purple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.title,
                                style: const TextStyle(
                                    fontSize: 15.5, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
                            const SizedBox(height: 2),
                            Text(widget.subtitle,
                                style: const TextStyle(fontSize: 12, color: HomeStyle.textSecondary)),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(Icons.keyboard_arrow_down_rounded, color: HomeStyle.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < widget.children.length; i++) ...[
                        widget.children[i],
                        if (i != widget.children.length - 1) const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
                secondChild: const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
