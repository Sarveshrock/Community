import 'package:flutter/material.dart';

import '../../../../core/widgets/form_section_card.dart';
import '../../../../core/widgets/multi_select_chips.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../domain/entities/hackathon.dart';

/// The Team Builder's "Looking For" list — structured roles, each with its
/// own optional priority/description/skills/experience level (spec section
/// 4), replacing the old flat "Roles needed (comma separated)" field.
/// Mirrors `JobQuestionsEditor`'s add-via-bottom-sheet pattern.
class TeamRoleEditor extends StatelessWidget {
  const TeamRoleEditor({super.key, required this.roles, required this.allSkillNames, required this.onChanged});

  final List<TeamRoleRequirement> roles;
  final List<String> allSkillNames;
  final ValueChanged<List<TeamRoleRequirement>> onChanged;

  Future<void> _addRole(BuildContext context) async {
    final role = await showModalBottomSheet<TeamRoleRequirement>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeStyle.cardBase,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddRoleSheet(allSkillNames: allSkillNames),
    );
    if (role == null) return;
    onChanged([...roles, role.copyWithOrder(roles.length)]);
  }

  void _remove(int index) {
    final next = [...roles]..removeAt(index);
    onChanged([for (var i = 0; i < next.length; i++) next[i].copyWithOrder(i)]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < roles.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RoleTile(role: roles[i], onRemove: () => _remove(i)),
          ),
        OutlinedButton.icon(
          onPressed: () => _addRole(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add another role'),
          style: OutlinedButton.styleFrom(
            foregroundColor: HomeStyle.purple,
            side: BorderSide(color: HomeStyle.purple.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }
}

extension on TeamRoleRequirement {
  TeamRoleRequirement copyWithOrder(int order) => TeamRoleRequirement(
        id: id,
        teamRequirementId: teamRequirementId,
        roleName: roleName,
        priority: priority,
        description: description,
        experienceLevel: experienceLevel,
        sortOrder: order,
        skillNames: skillNames,
      );
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({required this.role, required this.onRemove});

  final TeamRoleRequirement role;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (role.priority != null) '${role.priority} priority',
      if (role.experienceLevel != null) role.experienceLevel!,
      if (role.skillNames.isNotEmpty) role.skillNames.join(', '),
    ];
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role.roleName,
                    style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                if (subtitleParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitleParts.join(' · '), style: const TextStyle(fontSize: 12, color: HomeStyle.textSecondary)),
                ],
                if ((role.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(role.description!, style: const TextStyle(fontSize: 12, color: HomeStyle.textSecondary)),
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

class _AddRoleSheet extends StatefulWidget {
  const _AddRoleSheet({required this.allSkillNames});
  final List<String> allSkillNames;

  @override
  State<_AddRoleSheet> createState() => _AddRoleSheetState();
}

class _AddRoleSheetState extends State<_AddRoleSheet> {
  String? _roleName;
  final _customRoleController = TextEditingController();
  String? _priority;
  final _descriptionController = TextEditingController();
  String? _experienceLevel;
  final Set<String> _skills = {};

  @override
  void dispose() {
    _customRoleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final roleName = _roleName == 'Other' ? _customRoleController.text.trim() : (_roleName ?? '');
    if (roleName.isEmpty) return;
    Navigator.of(context).pop(TeamRoleRequirement(
      id: '',
      teamRequirementId: '',
      roleName: roleName,
      priority: _priority,
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      experienceLevel: _experienceLevel,
      skillNames: _skills.toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add a role', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _roleName,
              dropdownColor: HomeStyle.cardBase,
              style: const TextStyle(color: HomeStyle.textPrimary),
              decoration: darkInputDecoration('Role'),
              items: [for (final r in kTeamRoleOptions) DropdownMenuItem(value: r, child: Text(r))],
              onChanged: (v) => setState(() => _roleName = v),
            ),
            if (_roleName == 'Other') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customRoleController,
                style: const TextStyle(color: HomeStyle.textPrimary),
                decoration: darkInputDecoration('Role name'),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _priority,
              dropdownColor: HomeStyle.cardBase,
              style: const TextStyle(color: HomeStyle.textPrimary),
              decoration: darkInputDecoration('Priority (optional)'),
              items: [for (final p in kRolePriorities) DropdownMenuItem(value: p, child: Text(p))],
              onChanged: (v) => setState(() => _priority = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _experienceLevel,
              dropdownColor: HomeStyle.cardBase,
              style: const TextStyle(color: HomeStyle.textPrimary),
              decoration: darkInputDecoration('Experience level (optional)'),
              items: [for (final l in kExperienceLevelOptions) DropdownMenuItem(value: l, child: Text(l))],
              onChanged: (v) => setState(() => _experienceLevel = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              style: const TextStyle(color: HomeStyle.textPrimary),
              decoration: darkInputDecoration('Description (optional)'),
            ),
            const SizedBox(height: 12),
            const Text('Skills for this role', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 6),
            MultiSelectChips(
              options: widget.allSkillNames,
              selected: _skills,
              onChanged: (v) => setState(() {
                _skills
                  ..clear()
                  ..addAll(v);
              }),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('Add role')),
            ),
          ],
        ),
      ),
    );
  }
}
