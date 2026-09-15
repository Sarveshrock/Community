import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/models/skill.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../providers/interview_practice_providers.dart';

class EditInterviewPracticeProfileScreen extends ConsumerStatefulWidget {
  const EditInterviewPracticeProfileScreen({super.key});

  @override
  ConsumerState<EditInterviewPracticeProfileScreen> createState() =>
      _EditInterviewPracticeProfileScreenState();
}

class _EditInterviewPracticeProfileScreenState
    extends ConsumerState<EditInterviewPracticeProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roleController = TextEditingController();
  final _availabilityController = TextEditingController();
  final _topicController = TextEditingController();
  final Set<String> _topics = {};
  ExperienceLevel _level = ExperienceLevel.intermediate;
  bool _isActive = true;
  bool _loaded = false;

  void _addTopic() {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;
    setState(() {
      _topics.add(topic);
      _topicController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(interviewPracticeControllerProvider.notifier).upsertMyProfile({
      'target_role': _roleController.text.trim(),
      'topics': _topics.toList(),
      'experience_level': _level.value,
      'availability_notes': _availabilityController.text.trim().isEmpty
          ? null
          : _availabilityController.text.trim(),
      'is_active': _isActive,
    });
    if (success && mounted) {
      context.pop();
    } else if (mounted) {
      context.showSnack('Could not save your practice profile', isError: true);
    }
  }

  @override
  void dispose() {
    _roleController.dispose();
    _availabilityController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(interviewPracticeControllerProvider).isLoading;
    final myProfileAsync = ref.watch(myInterviewPracticeProfileProvider);

    myProfileAsync.whenData((profile) {
      if (!_loaded && profile != null) {
        _roleController.text = profile.targetRole;
        _availabilityController.text = profile.availabilityNotes ?? '';
        _topics.addAll(profile.topics);
        _level = profile.experienceLevel;
        _isActive = profile.isActive;
        _loaded = true;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Practice Profile')),
      body: ResponsiveCenter(
        maxWidth: 560,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join the mock-interview practice pool so other members can find and pair with you.',
                  style: context.textStyles.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _roleController,
                  decoration:
                      const InputDecoration(labelText: 'Role you\'re practicing for'),
                  validator: (v) => Validators.required(v, fieldName: 'Target role'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ExperienceLevel>(
                  initialValue: _level,
                  decoration: const InputDecoration(labelText: 'Experience level'),
                  items: [
                    for (final l in ExperienceLevel.values)
                      DropdownMenuItem(value: l, child: Text(l.label))
                  ],
                  onChanged: (v) => setState(() => _level = v ?? _level),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _availabilityController,
                  decoration: const InputDecoration(
                      labelText: 'Availability (optional)',
                      hintText: 'e.g. Weekday evenings, IST'),
                ),
                const SizedBox(height: 16),
                Text('Topics', style: context.textStyles.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _topicController,
                        decoration: const InputDecoration(
                            labelText: 'Add a topic', hintText: 'e.g. System Design'),
                        onSubmitted: (_) => _addTopic(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                        onPressed: _addTopic, icon: const Icon(Icons.add_circle_outline)),
                  ],
                ),
                if (_topics.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final topic in _topics)
                        Chip(
                          label: Text(topic),
                          onDeleted: () => setState(() => _topics.remove(topic)),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible in the practice pool'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: 12),
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
                        : const Text('Save'),
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
