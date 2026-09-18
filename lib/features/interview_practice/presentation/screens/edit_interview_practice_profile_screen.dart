import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/models/skill.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../home/presentation/widgets/home_style.dart';
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
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: HomeStyle.background,
        title: const Text('Practice Profile',
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Join the mock-interview practice pool so other members can find and pair with you.',
                    style: TextStyle(
                        fontSize: 13, color: HomeStyle.textSecondary),
                  ),
                ),
                const SizedBox(height: 14),
                FormSectionCard(
                  icon: Icons.record_voice_over_outlined,
                  title: 'Practice profile',
                  children: [
                    TextFormField(
                      controller: _roleController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration:
                          darkInputDecoration('Role you\'re practicing for'),
                      validator: (v) =>
                          Validators.required(v, fieldName: 'Target role'),
                    ),
                    DropdownButtonFormField<ExperienceLevel>(
                      isExpanded: true,
                      initialValue: _level,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Experience level'),
                      items: [
                        for (final l in ExperienceLevel.values)
                          DropdownMenuItem(value: l, child: Text(l.label))
                      ],
                      onChanged: (v) => setState(() => _level = v ?? _level),
                    ),
                    TextFormField(
                      controller: _availabilityController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration(
                          'Availability (optional)',
                          hint: 'e.g. Weekday evenings, IST'),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.sell_outlined,
                  title: 'Topics',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _topicController,
                            style: const TextStyle(
                                color: HomeStyle.textPrimary),
                            decoration: darkInputDecoration('Add a topic',
                                hint: 'e.g. System Design'),
                            onSubmitted: (_) => _addTopic(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: HomeStyle.purple.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _addTopic,
                            child: const Padding(
                              padding: EdgeInsets.all(13),
                              child: Icon(Icons.add_circle_outline,
                                  color: HomeStyle.purple, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_topics.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final topic in _topics)
                            _RemovableChip(
                              label: topic,
                              onRemove: () =>
                                  setState(() => _topics.remove(topic)),
                            ),
                        ],
                      ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.visibility_outlined,
                  title: 'Pool visibility',
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Visible in the practice pool',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: HomeStyle.textPrimary)),
                        ),
                        Switch(
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                          activeThumbColor: Colors.white,
                          activeTrackColor: HomeStyle.purple,
                          inactiveThumbColor: HomeStyle.textSecondary,
                          inactiveTrackColor:
                              Colors.white.withValues(alpha: 0.10),
                        ),
                      ],
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
                          : const Text('Save',
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

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: HomeStyle.purple.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: HomeStyle.purple.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: HomeStyle.purple)),
          const SizedBox(width: 2),
          InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 14, color: HomeStyle.purple),
            ),
          ),
        ],
      ),
    );
  }
}
