import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/multi_select_chips.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../profile/presentation/providers/profile_providers.dart' show allSkillsProvider;
import '../providers/hackathon_providers.dart';
import '../widgets/team_detail_view.dart';
import '../widgets/team_role_editor.dart';

/// The Team Builder. A single scrollable, sectioned form mirroring the
/// Jobs/Events/Mentor builder pattern, replacing the old single-page
/// "Find a Team" form. Also doubles as Edit Team when [editTeamRequirementId]
/// is set — same screen, same components, prefilled from the existing team.
class CreateTeamRequirementScreen extends ConsumerStatefulWidget {
  const CreateTeamRequirementScreen({
    super.key,
    this.hackathonId,
    this.hackathonName,
    this.editTeamRequirementId,
  });

  final String? hackathonId;
  final String? hackathonName;
  final String? editTeamRequirementId;

  @override
  ConsumerState<CreateTeamRequirementScreen> createState() => _CreateTeamRequirementScreenState();
}

class _CreateTeamRequirementScreenState extends ConsumerState<CreateTeamRequirementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hackathonNameController = TextEditingController();
  TextEditingController? _autocompleteController;
  final _teamNameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _teamSizeController = TextEditingController(text: '4');
  final _minTeamSizeController = TextEditingController();
  final _preferredTimesController = TextEditingController();
  final _timezoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _expectationsController = TextEditingController();
  final _githubController = TextEditingController();
  final _figmaController = TextEditingController();
  final _websiteController = TextEditingController();
  final _demoController = TextEditingController();
  final _pitchDeckController = TextEditingController();

  DateTime? _hackathonEventDate;
  bool _initialized = false;
  bool _reviewing = false;
  String? _existingHackathonName;
  String? _existingHackathonId;

  String? _projectStage;
  List<TeamRoleRequirement> _roles = [];
  final Set<String> _skillsWanted = {};
  final Set<String> _skillsHave = {};
  String? _commitment;
  String _collaborationMode = 'online';
  String? _communicationPlatform;
  String? _preferredExperienceLevel;
  final Set<String> _teamCulture = {};
  String _visibility = 'public';

  bool get _isEditing => widget.editTeamRequirementId != null;
  bool get _isExistingHackathon => widget.hackathonId != null;

  @override
  void dispose() {
    _hackathonNameController.dispose();
    _teamNameController.dispose();
    _taglineController.dispose();
    _descriptionController.dispose();
    _teamSizeController.dispose();
    _minTeamSizeController.dispose();
    _preferredTimesController.dispose();
    _timezoneController.dispose();
    _locationController.dispose();
    _expectationsController.dispose();
    _githubController.dispose();
    _figmaController.dispose();
    _websiteController.dispose();
    _demoController.dispose();
    _pitchDeckController.dispose();
    super.dispose();
  }

  void _hydrate(TeamRequirement team, String hackathonName) {
    if (_initialized) return;
    _existingHackathonId = team.hackathonId;
    _existingHackathonName = hackathonName;
    _teamNameController.text = team.teamName;
    _taglineController.text = team.tagline ?? '';
    _descriptionController.text = team.description ?? '';
    _teamSizeController.text = team.teamSize.toString();
    _minTeamSizeController.text = team.minTeamSize?.toString() ?? '';
    _preferredTimesController.text = team.preferredTimes ?? '';
    _timezoneController.text = team.timezone ?? '';
    _locationController.text = team.location ?? '';
    _expectationsController.text = team.expectations ?? '';
    _githubController.text = team.githubUrl ?? '';
    _figmaController.text = team.figmaUrl ?? '';
    _websiteController.text = team.websiteUrl ?? '';
    _demoController.text = team.demoUrl ?? '';
    _pitchDeckController.text = team.pitchDeckUrl ?? '';
    _projectStage = team.projectStage;
    _roles = team.roleRequirements;
    _skillsWanted
      ..clear()
      ..addAll(team.requiredSkillNames);
    _skillsHave
      ..clear()
      ..addAll(team.skillsHaveNames);
    _commitment = team.commitment;
    _collaborationMode = team.collaborationMode;
    _communicationPlatform = team.communicationPlatform;
    _preferredExperienceLevel = team.preferredExperienceLevel;
    _teamCulture
      ..clear()
      ..addAll(team.teamCulture);
    _visibility = team.visibility;
    _initialized = true;
  }

  Future<void> _pickEventDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hackathonEventDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _hackathonEventDate = picked);
  }

  Map<String, dynamic> _buildData() {
    final teamSize = int.tryParse(_teamSizeController.text.trim()) ?? 4;
    return {
      'team_name': _teamNameController.text.trim(),
      'tagline': _taglineController.text.trim().isEmpty ? null : _taglineController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      'project_stage': _projectStage,
      'team_size': teamSize,
      'min_team_size': int.tryParse(_minTeamSizeController.text.trim()),
      'commitment': _commitment,
      'preferred_times': _preferredTimesController.text.trim().isEmpty ? null : _preferredTimesController.text.trim(),
      'timezone': _timezoneController.text.trim().isEmpty ? null : _timezoneController.text.trim(),
      'collaboration_mode': _collaborationMode,
      'location': (_collaborationMode == 'in_person' || _collaborationMode == 'hybrid') &&
              _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null,
      'communication_platform': (_collaborationMode == 'online' || _collaborationMode == 'hybrid')
          ? _communicationPlatform
          : null,
      'preferred_experience_level': _preferredExperienceLevel,
      'team_culture': _teamCulture.toList(),
      'expectations': _expectationsController.text.trim().isEmpty ? null : _expectationsController.text.trim(),
      'github_url': _githubController.text.trim().isEmpty ? null : _githubController.text.trim(),
      'figma_url': _figmaController.text.trim().isEmpty ? null : _figmaController.text.trim(),
      'website_url': _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      'demo_url': _demoController.text.trim().isEmpty ? null : _demoController.text.trim(),
      'pitch_deck_url': _pitchDeckController.text.trim().isEmpty ? null : _pitchDeckController.text.trim(),
      'visibility': _visibility,
    };
  }

  TeamRequirement _previewTeam() {
    final teamSize = int.tryParse(_teamSizeController.text.trim()) ?? 4;
    return TeamRequirement(
      id: widget.editTeamRequirementId ?? 'preview',
      hackathonId: _existingHackathonId ?? '',
      creatorId: '',
      teamName: _teamNameController.text.trim().isEmpty ? 'Untitled team' : _teamNameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      teamSize: teamSize,
      tagline: _taglineController.text.trim().isEmpty ? null : _taglineController.text.trim(),
      projectStage: _projectStage,
      minTeamSize: int.tryParse(_minTeamSizeController.text.trim()),
      commitment: _commitment,
      preferredTimes: _preferredTimesController.text.trim().isEmpty ? null : _preferredTimesController.text.trim(),
      timezone: _timezoneController.text.trim().isEmpty ? null : _timezoneController.text.trim(),
      collaborationMode: _collaborationMode,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      communicationPlatform: _communicationPlatform,
      preferredExperienceLevel: _preferredExperienceLevel,
      teamCulture: _teamCulture.toList(),
      expectations: _expectationsController.text.trim().isEmpty ? null : _expectationsController.text.trim(),
      githubUrl: _githubController.text.trim().isEmpty ? null : _githubController.text.trim(),
      figmaUrl: _figmaController.text.trim().isEmpty ? null : _figmaController.text.trim(),
      websiteUrl: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      demoUrl: _demoController.text.trim().isEmpty ? null : _demoController.text.trim(),
      pitchDeckUrl: _pitchDeckController.text.trim().isEmpty ? null : _pitchDeckController.text.trim(),
      visibility: _visibility,
      roleRequirements: _roles,
      requiredSkillNames: _skillsWanted.toList(),
      skillsHaveNames: _skillsHave.toList(),
    );
  }

  bool _validate() {
    if (!_formKey.currentState!.validate()) return false;
    if (!_isExistingHackathon &&
        !_isEditing &&
        (_autocompleteController?.text ?? _hackathonNameController.text).trim().isEmpty) {
      context.showSnack('Add a hackathon name', isError: true);
      return false;
    }
    if (_descriptionController.text.trim().isEmpty && _taglineController.text.trim().isEmpty) {
      context.showSnack('Add a tagline or project description', isError: true);
      return false;
    }
    final teamSize = int.tryParse(_teamSizeController.text.trim());
    if (teamSize == null || teamSize < 1) {
      context.showSnack('Enter a valid team size', isError: true);
      return false;
    }
    final minSize = int.tryParse(_minTeamSizeController.text.trim());
    if (minSize != null && minSize > teamSize) {
      context.showSnack('Minimum team size can\'t exceed the maximum', isError: true);
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    final skills = ref.read(allSkillsProvider).valueOrNull ?? const [];
    final wantedIds = [for (final s in skills) if (_skillsWanted.contains(s.name)) s.id];
    final haveIds = [for (final s in skills) if (_skillsHave.contains(s.name)) s.id];

    if (_isEditing) {
      final ok = await ref.read(hackathonControllerProvider.notifier).updateTeamRequirement(
            widget.editTeamRequirementId!,
            _existingHackathonId!,
            _buildData(),
            skillIds: wantedIds,
            skillsHaveIds: haveIds,
            roles: _roles,
          );
      if (!mounted) return;
      if (ok) {
        context.showSnack('Team updated');
        context.pop();
      } else {
        context.showSnack('Could not update team', isError: true);
      }
      return;
    }

    final success = await ref.read(hackathonControllerProvider.notifier).createTeamRequirement(
          hackathonId: widget.hackathonId,
          hackathonName: _isExistingHackathon
              ? null
              : (_autocompleteController?.text ?? _hackathonNameController.text).trim(),
          hackathonEventDate: _hackathonEventDate,
          data: _buildData(),
          skillIds: wantedIds,
          skillsHaveIds: haveIds,
          roles: _roles,
        );
    if (success && mounted) {
      context.pop();
    } else if (mounted) {
      context.showSnack('Could not post team', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      final teamAsync = ref.watch(teamDetailProvider(widget.editTeamRequirementId!));
      if (teamAsync.isLoading) {
        return const Scaffold(backgroundColor: HomeStyle.background, body: LoadingState());
      }
      if (teamAsync.hasError) {
        return Scaffold(backgroundColor: HomeStyle.background, body: ErrorState(message: teamAsync.error.toString()));
      }
      final team = teamAsync.value!;
      final hackathonAsync = ref.watch(hackathonDetailProvider(team.hackathonId));
      _hydrate(team, hackathonAsync.valueOrNull?.name ?? '');
    }
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) {
    final isSaving = ref.watch(hackathonControllerProvider).isLoading;
    final skillsAsync = ref.watch(allSkillsProvider);
    final existingHackathonsAsync = ref.watch(hackathonsListProvider);

    if (_reviewing) {
      return Scaffold(
        backgroundColor: HomeStyle.background,
        appBar: AppBar(
          backgroundColor: HomeStyle.background,
          title: const Text('Preview', style: TextStyle(color: HomeStyle.textPrimary)),
          iconTheme: const IconThemeData(color: HomeStyle.textPrimary),
        ),
        body: ResponsiveCenter(
          maxWidth: 560,
          child: Column(
            children: [
              Expanded(
                child: TeamDetailView(
                  team: _previewTeam(),
                  hackathonName: _existingHackathonName ??
                      widget.hackathonName ??
                      (_autocompleteController?.text ?? _hackathonNameController.text),
                  hackathonEventDate: _hackathonEventDate,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: () => setState(() => _reviewing = false), child: const Text('Back to edit')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: isSaving ? null : _submit,
                          child: isSaving
                              ? const SizedBox(
                                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_isEditing ? 'Save changes' : 'Post team'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: HomeStyle.background,
        title: Text(_isEditing ? 'Edit Team' : 'Post a Team', style: const TextStyle(color: HomeStyle.textPrimary)),
        iconTheme: const IconThemeData(color: HomeStyle.textPrimary),
        actions: [
          TextButton(
            onPressed: () {
              if (_validate()) setState(() => _reviewing = true);
            },
            child: const Text('Preview'),
          ),
        ],
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
                if (!_isEditing)
                  FormSectionCard(
                    icon: Icons.bolt_outlined,
                    title: 'Hackathon',
                    children: [
                      if (_isExistingHackathon)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.bolt_outlined, color: HomeStyle.purple, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(widget.hackathonName ?? '',
                                    style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        existingHackathonsAsync.when(
                          data: (existing) => Autocomplete<String>(
                            optionsBuilder: (value) {
                              if (value.text.trim().isEmpty) return const Iterable<String>.empty();
                              return existing
                                  .map((h) => h.name)
                                  .where((name) => name.toLowerCase().contains(value.text.trim().toLowerCase()));
                            },
                            fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                              _autocompleteController = controller;
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                style: const TextStyle(color: HomeStyle.textPrimary),
                                decoration: darkInputDecoration('Hackathon name', hint: 'e.g. Smart India Hackathon 2026'),
                                validator: (v) => Validators.required(v, fieldName: 'Hackathon name'),
                              );
                            },
                          ),
                          loading: () => TextFormField(
                            controller: _hackathonNameController,
                            style: const TextStyle(color: HomeStyle.textPrimary),
                            decoration: darkInputDecoration('Hackathon name'),
                            validator: (v) => Validators.required(v, fieldName: 'Hackathon name'),
                          ),
                          error: (_, __) => TextFormField(
                            controller: _hackathonNameController,
                            style: const TextStyle(color: HomeStyle.textPrimary),
                            decoration: darkInputDecoration('Hackathon name'),
                            validator: (v) => Validators.required(v, fieldName: 'Hackathon name'),
                          ),
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton(
                          onPressed: _pickEventDate,
                          child: Text(_hackathonEventDate == null
                              ? 'Hackathon date (optional)'
                              : DateFormat.yMMMd().format(_hackathonEventDate!)),
                        ),
                      ],
                    ],
                  ),
                FormSectionCard(
                  icon: Icons.groups_2_outlined,
                  title: 'Team basics',
                  children: [
                    TextFormField(
                      controller: _teamNameController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Team name'),
                      validator: (v) => Validators.required(v, fieldName: 'Team name'),
                    ),
                    TextFormField(
                      controller: _taglineController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Team tagline (optional)', hint: 'One line that sells your team'),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'Project',
                  children: [
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Project idea', hint: 'What are you building?'),
                    ),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _projectStage,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Current stage (optional)'),
                      items: [for (final s in kProjectStages) DropdownMenuItem(value: s, child: Text(s))],
                      onChanged: (v) => setState(() => _projectStage = v),
                    ),
                  ],
                ),
                if (_isEditing)
                  FormSectionCard(
                    icon: Icons.diversity_3_outlined,
                    title: 'Current team',
                    subtitle: 'Manage members and invitations from the Team Page',
                    children: [
                      Text(
                        '${ref.watch(teamDetailProvider(widget.editTeamRequirementId!)).valueOrNull?.memberCount ?? '—'} / ${_teamSizeController.text} members',
                        style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                FormSectionCard(
                  icon: Icons.person_search_outlined,
                  title: 'Looking for',
                  subtitle: 'Add each role you still need, with optional priority/skills/experience',
                  children: [
                    TeamRoleEditor(
                      roles: _roles,
                      allSkillNames: skillsAsync.valueOrNull?.map((s) => s.name).toList() ?? const [],
                      onChanged: (v) => setState(() => _roles = v),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.psychology_outlined,
                  title: 'Skills',
                  children: [
                    const Text('Skills we have', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    skillsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Could not load skills'),
                      data: (skills) => MultiSelectChips(
                        options: [for (final s in skills) s.name],
                        selected: _skillsHave,
                        onChanged: (v) => setState(() {
                          _skillsHave
                            ..clear()
                            ..addAll(v);
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Skills we\'re looking for', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    skillsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Could not load skills'),
                      data: (skills) => MultiSelectChips(
                        options: [for (final s in skills) s.name],
                        selected: _skillsWanted,
                        onChanged: (v) => setState(() {
                          _skillsWanted
                            ..clear()
                            ..addAll(v);
                        }),
                      ),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.numbers_rounded,
                  title: 'Team size',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minTeamSizeController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: HomeStyle.textPrimary),
                            decoration: darkInputDecoration('Minimum (optional)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _teamSizeController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: HomeStyle.textPrimary),
                            decoration: darkInputDecoration('Maximum'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                CollapsibleFormSection(
                  icon: Icons.schedule_outlined,
                  title: 'Availability & commitment',
                  subtitle: 'How much time this team expects, and when',
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _commitment,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Expected commitment (optional)'),
                      items: [for (final c in kCommitmentOptions) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => setState(() => _commitment = v),
                    ),
                    TextFormField(
                      controller: _preferredTimesController,
                      maxLines: 2,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Preferred collaboration times (optional)',
                          hint: 'e.g. Weekdays 7-10 PM, weekends flexible'),
                    ),
                    TextFormField(
                      controller: _timezoneController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Timezone (optional)', hint: 'e.g. IST'),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.hub_outlined,
                  title: 'Collaboration',
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _collaborationMode,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Mode'),
                      items: [
                        for (final m in kCollaborationModes) DropdownMenuItem(value: m, child: Text(collaborationModeLabel(m))),
                      ],
                      onChanged: (v) => setState(() => _collaborationMode = v ?? _collaborationMode),
                    ),
                    if (_collaborationMode == 'in_person' || _collaborationMode == 'hybrid')
                      TextFormField(
                        controller: _locationController,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Location'),
                      ),
                    if (_collaborationMode == 'online' || _collaborationMode == 'hybrid')
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _communicationPlatform,
                        dropdownColor: HomeStyle.cardBase,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Preferred communication platform (optional)'),
                        items: [for (final p in kCommunicationPlatforms) DropdownMenuItem(value: p, child: Text(p))],
                        onChanged: (v) => setState(() => _communicationPlatform = v),
                      ),
                  ],
                ),
                CollapsibleFormSection(
                  icon: Icons.tune_rounded,
                  title: 'Team preferences',
                  subtitle: 'Preferred experience level and team culture',
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _preferredExperienceLevel,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Preferred experience level (optional)'),
                      items: [for (final l in kExperienceLevelOptions) DropdownMenuItem(value: l, child: Text(l))],
                      onChanged: (v) => setState(() => _preferredExperienceLevel = v),
                    ),
                    const SizedBox(height: 4),
                    const Text('Team culture', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    MultiSelectChips(
                      options: kTeamCultureOptions,
                      selected: _teamCulture,
                      onChanged: (v) => setState(() {
                        _teamCulture
                          ..clear()
                          ..addAll(v);
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _expectationsController,
                      maxLines: 3,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('What we expect from teammates (optional)'),
                    ),
                  ],
                ),
                CollapsibleFormSection(
                  icon: Icons.link_rounded,
                  title: 'Project links',
                  subtitle: 'Optional — only shown if provided',
                  children: [
                    TextFormField(
                      controller: _githubController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('GitHub'),
                      validator: Validators.url,
                    ),
                    TextFormField(
                      controller: _figmaController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Figma'),
                      validator: Validators.url,
                    ),
                    TextFormField(
                      controller: _websiteController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Project website'),
                      validator: Validators.url,
                    ),
                    TextFormField(
                      controller: _demoController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Demo'),
                      validator: Validators.url,
                    ),
                    TextFormField(
                      controller: _pitchDeckController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Pitch deck'),
                      validator: Validators.url,
                    ),
                  ],
                ),
                CollapsibleFormSection(
                  icon: Icons.visibility_outlined,
                  title: 'Advanced',
                  subtitle: 'Who can see this team',
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _visibility,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Visibility'),
                      items: [
                        for (final v in kTeamVisibilityOptions) DropdownMenuItem(value: v, child: Text(teamVisibilityLabel(v))),
                      ],
                      onChanged: (v) => setState(() => _visibility = v ?? _visibility),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: isSaving
                          ? null
                          : () {
                              if (_validate()) setState(() => _reviewing = true);
                            },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: HomeStyle.brandGradient,
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: HomeStyle.glow(HomeStyle.purple, opacity: 0.3),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Preview',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
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
