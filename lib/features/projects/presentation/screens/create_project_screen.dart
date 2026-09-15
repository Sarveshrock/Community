import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/project_providers.dart';

class CreateProjectScreen extends ConsumerStatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  ConsumerState<CreateProjectScreen> createState() =>
      _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  CollaborationType _collaborationType = CollaborationType.personal;
  CompensationType _compensationType = CompensationType.unpaid;
  final Set<String> _selectedSkillIds = {};

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success =
        await ref.read(projectControllerProvider.notifier).createProject(
      {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'category': _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        'collaboration_type': _collaborationType.value,
        'compensation_type': _compensationType.value,
      },
      _selectedSkillIds.toList(),
    );
    if (success && mounted) {
      context.pop();
    } else if (mounted) {
      context.showSnack('Could not create project', isError: true);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(projectControllerProvider).isLoading;
    final skillsAsync = ref.watch(allSkillsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Project')),
      body: ResponsiveCenter(
        maxWidth: 560,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Project title'),
                  validator: (v) => Validators.required(v, fieldName: 'Title'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'What are you building?',
                      alignLabelWithHint: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(labelText: 'Category')),
                const SizedBox(height: 12),
                DropdownButtonFormField<CollaborationType>(
                  initialValue: _collaborationType,
                  decoration:
                      const InputDecoration(labelText: 'Collaboration type'),
                  items: [
                    for (final c in CollaborationType.values)
                      DropdownMenuItem(value: c, child: Text(c.label))
                  ],
                  onChanged: (v) => setState(
                      () => _collaborationType = v ?? _collaborationType),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CompensationType>(
                  initialValue: _compensationType,
                  decoration: const InputDecoration(labelText: 'Compensation'),
                  items: [
                    for (final c in CompensationType.values)
                      DropdownMenuItem(value: c, child: Text(c.label))
                  ],
                  onChanged: (v) => setState(
                      () => _compensationType = v ?? _compensationType),
                ),
                const SizedBox(height: 16),
                Text('Skills needed', style: context.textStyles.titleSmall),
                const SizedBox(height: 8),
                skillsAsync.when(
                  data: (skills) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final skill in skills)
                        FilterChip(
                          label: Text(skill.name),
                          selected: _selectedSkillIds.contains(skill.id),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _selectedSkillIds.add(skill.id)
                                : _selectedSkillIds.remove(skill.id);
                          }),
                        ),
                    ],
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Could not load skills'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isSaving ? null : _submit,
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Post project'),
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
