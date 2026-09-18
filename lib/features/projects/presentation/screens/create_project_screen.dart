import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../../core/widgets/multi_select_chips.dart';
import '../../../home/presentation/widgets/home_style.dart';
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
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: HomeStyle.background,
        title: const Text('New Project',
            style: TextStyle(color: HomeStyle.textPrimary)),
        iconTheme: const IconThemeData(color: HomeStyle.textPrimary),
      ),
      body: ResponsiveCenter(
        maxWidth: 560,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FormSectionCard(
                  icon: Icons.info_outline_rounded,
                  title: 'Project basics',
                  children: [
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Project title'),
                      validator: (v) => Validators.required(v, fieldName: 'Title'),
                    ),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration:
                          darkInputDecoration('What are you building?'),
                    ),
                    TextFormField(
                      controller: _categoryController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Category'),
                    ),
                    DropdownButtonFormField<CollaborationType>(
                      isExpanded: true,
                      initialValue: _collaborationType,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Collaboration type'),
                      items: [
                        for (final c in CollaborationType.values)
                          DropdownMenuItem(value: c, child: Text(c.label))
                      ],
                      onChanged: (v) => setState(
                          () => _collaborationType = v ?? _collaborationType),
                    ),
                    DropdownButtonFormField<CompensationType>(
                      isExpanded: true,
                      initialValue: _compensationType,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Compensation'),
                      items: [
                        for (final c in CompensationType.values)
                          DropdownMenuItem(value: c, child: Text(c.label))
                      ],
                      onChanged: (v) => setState(
                          () => _compensationType = v ?? _compensationType),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.sell_outlined,
                  title: 'Skills needed',
                  children: [
                    skillsAsync.when(
                      loading: () =>
                          const LinearProgressIndicator(color: HomeStyle.purple),
                      error: (_, __) => const Text('Could not load skills',
                          style: TextStyle(color: HomeStyle.textSecondary)),
                      data: (skills) => MultiSelectChips(
                        options: [for (final s in skills) s.name],
                        selected: {
                          for (final s in skills)
                            if (_selectedSkillIds.contains(s.id)) s.name
                        },
                        onChanged: (selectedNames) => setState(() {
                          _selectedSkillIds
                            ..clear()
                            ..addAll([
                              for (final s in skills)
                                if (selectedNames.contains(s.name)) s.id
                            ]);
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: isSaving ? null : _submit,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: HomeStyle.brandGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Post project',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                    ),
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
