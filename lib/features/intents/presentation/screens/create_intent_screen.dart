import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/multi_select_chips.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../jobs/domain/entities/job.dart' show WorkMode, WorkModeX;
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/intent_config.dart';
import '../providers/intent_providers.dart';
import '../widgets/intent_detail_view.dart';

class _Duration {
  const _Duration(this.label, this.days);
  final String label;
  final int? days; // null = custom
}

const _durations = [
  _Duration('7 days', 7),
  _Duration('14 days', 14),
  _Duration('30 days', 30),
  _Duration('Custom', null),
];

/// The intent-type picker's menu shows exactly these 9 canonical categories
/// (per the redesigned Create Intent UI) rather than every [IntentType]
/// value — several enum values are finer-grained variants of one of these
/// (e.g. `findDeveloper`/`findDesigner`/`findOpenSourceContributor` are all
/// flavors of "Find Collaborator") kept only for backward compatibility with
/// intents already posted under them. Editing an existing intent of a
/// non-listed type still works — it just won't be highlighted as selected in
/// this curated menu.
const _pickerIntentTypes = [
  IntentType.findCollaborator,
  IntentType.findJob,
  IntentType.findMentor,
  IntentType.offerMentorship,
  IntentType.findHackathonTeam,
  IntentType.findCofounder,
  IntentType.networking,
  IntentType.findProject,
  IntentType.findStudyPartner,
];

// Fixed metadata keys for the generic "Additional details" section — these
// apply to any Intent type (unlike intentTypeConfig's per-type fields), so
// they live outside the type-keyed dynamic field cache and are always
// included, never dropped when the Intent type changes.
const _kLinkGithub = 'link_github';
const _kLinkFigma = 'link_figma';
const _kLinkPortfolio = 'link_portfolio';
const _kAdditionalNotes = 'additional_notes';

/// The Intent Builder — a single mobile-first scrollable page (no
/// multi-step/N-of-9 flow): Intent type (one dropdown), Basic information,
/// an Intent-specific section driven entirely by [intentTypeConfig] (never a
/// hardcoded if/else chain — see `domain/intent_config.dart`'s doc comment),
/// Skills, Preferences, Additional details, Visibility & expiry, then a live
/// Preview, with a single sticky "Post Intent" action at the bottom. Also
/// doubles as the Edit Intent screen when [editIntentId] is set.
///
/// Switching Intent type never loses what was typed for the previous type:
/// each dynamic field's on-screen controller/value is cached per
/// `(type, fieldKey)`, so switching back during the same session restores it
/// — but only the *current* type's fields are ever read into the metadata
/// that gets saved, so a previous type's values never leak into the record.
class CreateIntentScreen extends ConsumerStatefulWidget {
  const CreateIntentScreen({super.key, this.editIntentId});

  final String? editIntentId;

  @override
  ConsumerState<CreateIntentScreen> createState() => _CreateIntentScreenState();
}

class _CreateIntentScreenState extends ConsumerState<CreateIntentScreen> {
  final _intentFieldKey = GlobalKey();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _preferredRoleController = TextEditingController();
  final _locationController = TextEditingController();
  final _commitmentController = TextEditingController();
  final _githubController = TextEditingController();
  final _figmaController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _notesController = TextEditingController();

  bool _initialized = false;
  IntentType _intentType = IntentType.findCollaborator;
  ExperienceLevel _experienceLevel = ExperienceLevel.intermediate;
  WorkMode? _workMode;
  IntentVisibility _visibility = IntentVisibility.public;
  final Set<String> _skillsNeeded = {};
  final Set<String> _skillsOffered = {};
  _Duration _duration = _durations.first;
  DateTime? _customExpiry;

  // Dynamic (per intent-type) field state, cached per "type:fieldKey" so
  // switching types back and forth during one session keeps what was typed.
  final Map<String, TextEditingController> _dynControllers = {};
  final Map<String, String?> _dynDropdowns = {};
  final Map<String, Set<String>> _dynMultiSelects = {};

  bool get _isEditing => widget.editIntentId != null;

  // Live Preview must "update automatically as the user fills the form" —
  // plain typing into a TextEditingController doesn't trigger a rebuild on
  // its own, so every text field feeding the preview is wired to repaint it.
  void _refreshPreview() => setState(() {});

  String _dynKey(IntentFieldSpec f) => '${_intentType.value}:${f.key}';

  TextEditingController _dynController(IntentFieldSpec f) => _dynControllers.putIfAbsent(_dynKey(f), () {
        final controller = TextEditingController();
        controller.addListener(_refreshPreview);
        return controller;
      });

  Set<String> _dynMultiSelect(IntentFieldSpec f) =>
      _dynMultiSelects.putIfAbsent(_dynKey(f), () => <String>{});

  void _hydrateDynamicFields(UserIntent intent) {
    // Called right after `_intentType = intent.intentType`, so `_dynKey`
    // (keyed off `_intentType`) lines up with this intent's own fields —
    // and routing through `_dynController` (rather than a bare
    // `TextEditingController()`) keeps the live-preview listener wired up
    // for hydrated values too.
    final config = intentTypeConfig(intent.intentType);
    for (final field in config.fields) {
      final key = _dynKey(field);
      final value = intent.metadata[field.key];
      if (value == null) continue;
      switch (field.kind) {
        case IntentFieldKind.text:
        case IntentFieldKind.multilineText:
        case IntentFieldKind.number:
          _dynController(field).text = value.toString();
        case IntentFieldKind.dropdown:
          _dynDropdowns[key] = value.toString();
        case IntentFieldKind.multiSelect:
          _dynMultiSelects[key] = (value as List).map((e) => e.toString()).toSet();
      }
    }
  }

  void _hydrate(UserIntent intent, List<Skill> allSkills) {
    if (_initialized) return;
    _intentType = intent.intentType;
    _titleController.text = intent.title;
    _descriptionController.text = intent.description ?? '';
    _experienceLevel = intent.experienceLevel;
    _preferredRoleController.text = intent.preferredRole ?? '';
    _locationController.text = intent.locationPreference ?? '';
    _workMode = intent.workMode == null ? null : WorkModeX.fromValue(intent.workMode);
    _commitmentController.text = intent.commitmentLevel ?? '';
    _visibility = intent.visibility;
    _skillsNeeded
      ..clear()
      ..addAll([for (final s in allSkills) if (intent.skillsNeeded.contains(s.name)) s.id]);
    _skillsOffered
      ..clear()
      ..addAll([for (final s in allSkills) if (intent.skillsOffered.contains(s.name)) s.id]);
    _githubController.text = (intent.metadata[_kLinkGithub] as String?) ?? '';
    _figmaController.text = (intent.metadata[_kLinkFigma] as String?) ?? '';
    _portfolioController.text = (intent.metadata[_kLinkPortfolio] as String?) ?? '';
    _notesController.text = (intent.metadata[_kAdditionalNotes] as String?) ?? '';
    _hydrateDynamicFields(intent);
    _initialized = true;
  }

  List<TextEditingController> get _previewControllers => [
        _titleController,
        _descriptionController,
        _preferredRoleController,
        _locationController,
        _commitmentController,
        _githubController,
        _figmaController,
        _portfolioController,
        _notesController,
      ];

  @override
  void initState() {
    super.initState();
    for (final c in _previewControllers) {
      c.addListener(_refreshPreview);
    }
  }

  @override
  void dispose() {
    for (final c in _previewControllers) {
      c.dispose();
    }
    for (final c in _dynControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCustomExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _customExpiry = picked);
  }

  Map<String, dynamic> _buildMetadata() {
    final config = intentTypeConfig(_intentType);
    final data = <String, dynamic>{};
    for (final field in config.fields) {
      switch (field.kind) {
        case IntentFieldKind.text:
        case IntentFieldKind.multilineText:
          final t = _dynController(field).text.trim();
          if (t.isNotEmpty) data[field.key] = t;
        case IntentFieldKind.number:
          final n = int.tryParse(_dynController(field).text.trim());
          if (n != null) data[field.key] = n;
        case IntentFieldKind.dropdown:
          final v = _dynDropdowns[_dynKey(field)];
          if (v != null) data[field.key] = v;
        case IntentFieldKind.multiSelect:
          final s = _dynMultiSelect(field);
          if (s.isNotEmpty) data[field.key] = s.toList();
      }
    }
    if (_githubController.text.trim().isNotEmpty) data[_kLinkGithub] = _githubController.text.trim();
    if (_figmaController.text.trim().isNotEmpty) data[_kLinkFigma] = _figmaController.text.trim();
    if (_portfolioController.text.trim().isNotEmpty) data[_kLinkPortfolio] = _portfolioController.text.trim();
    if (_notesController.text.trim().isNotEmpty) data[_kAdditionalNotes] = _notesController.text.trim();
    return data;
  }

  DateTime? _resolveExpiry() {
    if (_duration.days != null) return DateTime.now().add(Duration(days: _duration.days!));
    return _customExpiry;
  }

  Widget _buildDynField(IntentFieldSpec field) {
    switch (field.kind) {
      case IntentFieldKind.text:
        return TextFormField(
          controller: _dynController(field),
          style: const TextStyle(color: HomeStyle.textPrimary),
          decoration: darkInputDecoration(field.label, hint: field.hint),
        );
      case IntentFieldKind.multilineText:
        return TextFormField(
          controller: _dynController(field),
          maxLines: 4,
          style: const TextStyle(color: HomeStyle.textPrimary),
          decoration: darkInputDecoration(field.label, hint: field.hint),
        );
      case IntentFieldKind.number:
        return TextFormField(
          controller: _dynController(field),
          keyboardType: TextInputType.number,
          style: const TextStyle(color: HomeStyle.textPrimary),
          decoration: darkInputDecoration(field.label, hint: field.hint),
        );
      case IntentFieldKind.dropdown:
        return DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _dynDropdowns[_dynKey(field)],
          dropdownColor: HomeStyle.cardBase,
          style: const TextStyle(color: HomeStyle.textPrimary),
          decoration: darkInputDecoration(field.label, hint: field.hint),
          items: [for (final o in field.options) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (v) => setState(() => _dynDropdowns[_dynKey(field)] = v),
        );
      case IntentFieldKind.multiSelect:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            MultiSelectChips(
              options: field.options,
              selected: _dynMultiSelect(field),
              onChanged: (next) => setState(() => _dynMultiSelects[_dynKey(field)] = next),
            ),
          ],
        );
    }
  }

  Future<void> _openIntentTypeMenu() async {
    final box = _intentFieldKey.currentContext!.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset(0, box.size.height + 6), ancestor: overlay);
    final bottomRight = box.localToGlobal(box.size.bottomRight(const Offset(0, 6)), ancestor: overlay);
    final position = RelativeRect.fromRect(Rect.fromPoints(topLeft, bottomRight), Offset.zero & overlay.size);

    final selected = await showMenu<IntentType>(
      context: context,
      position: position,
      color: HomeStyle.cardBase,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      constraints: BoxConstraints(minWidth: box.size.width, maxWidth: box.size.width),
      items: [
        for (final t in _pickerIntentTypes)
          PopupMenuItem<IntentType>(
            value: t,
            padding: EdgeInsets.zero,
            child: _IntentTypeMenuRow(type: t, selected: t == _intentType),
          ),
      ],
    );
    if (selected != null) setState(() => _intentType = selected);
  }

  Future<void> _showHelpDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: HomeStyle.cardBase,
        title: const Text('What is an Intent?', style: TextStyle(color: HomeStyle.textPrimary)),
        content: const Text(
          'An Intent tells the community what you\'re currently looking for — a collaborator, a job, a mentor, and more. '
          'Others can discover it and connect with you directly.',
          style: TextStyle(color: HomeStyle.textSecondary),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it'))],
      ),
    );
  }

  UserIntent _buildPreviewIntent(List<Skill> skills) {
    final expiresAt = _resolveExpiry() ?? DateTime.now().add(const Duration(days: 30));
    return UserIntent(
      id: widget.editIntentId ?? 'preview',
      profileId: '',
      intentType: _intentType,
      title: _titleController.text.trim().isEmpty ? 'Untitled intent' : _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      experienceLevel: _experienceLevel,
      preferredRole: _preferredRoleController.text.trim().isEmpty ? null : _preferredRoleController.text.trim(),
      locationPreference: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      workMode: _workMode?.value,
      commitmentLevel: _commitmentController.text.trim().isEmpty ? null : _commitmentController.text.trim(),
      visibility: _visibility,
      expiresAt: expiresAt,
      createdAt: DateTime.now(),
      skillsNeeded: [for (final s in skills) if (_skillsNeeded.contains(s.id)) s.name],
      skillsOffered: [for (final s in skills) if (_skillsOffered.contains(s.id)) s.name],
      metadata: _buildMetadata(),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_skillsNeeded.isEmpty || _skillsOffered.isEmpty) {
      context.showSnack('Add at least one skill you need and one you can offer', isError: true);
      return;
    }
    final expiresAt = _resolveExpiry();
    if (expiresAt == null) {
      context.showSnack('Choose an expiration date', isError: true);
      return;
    }

    final data = {
      'intent_type': _intentType.value,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      'experience_level': _experienceLevel.value,
      'preferred_role': _preferredRoleController.text.trim().isEmpty ? null : _preferredRoleController.text.trim(),
      'location_preference': _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      'work_mode': _workMode?.value,
      'commitment_level': _commitmentController.text.trim().isEmpty ? null : _commitmentController.text.trim(),
      'visibility': _visibility.value,
      'expires_at': expiresAt.toIso8601String(),
      'metadata': _buildMetadata(),
    };

    final controller = ref.read(intentControllerProvider.notifier);
    final bool success;
    if (_isEditing) {
      success = await controller.updateIntent(
        widget.editIntentId!,
        data,
        skillsNeededIds: _skillsNeeded.toList(),
        skillsOfferedIds: _skillsOffered.toList(),
      );
    } else {
      success = await controller.createIntent(
        data,
        skillsNeededIds: _skillsNeeded.toList(),
        skillsOfferedIds: _skillsOffered.toList(),
      );
    }
    if (success && mounted) {
      context.showSnack(_isEditing ? 'Intent updated' : 'Intent posted');
      context.pop();
    } else if (mounted) {
      context.showSnack('Could not save this intent', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      final intentAsync = ref.watch(intentDetailProvider(widget.editIntentId!));
      final skillsAsync = ref.watch(allSkillsProvider);
      if (intentAsync.isLoading || skillsAsync.isLoading) {
        return const Scaffold(backgroundColor: HomeStyle.background, body: LoadingState());
      }
      if (intentAsync.hasError) {
        return Scaffold(backgroundColor: HomeStyle.background, body: ErrorState(message: intentAsync.error.toString()));
      }
      if (skillsAsync.hasError) {
        return Scaffold(backgroundColor: HomeStyle.background, body: ErrorState(message: skillsAsync.error.toString()));
      }
      _hydrate(intentAsync.requireValue, skillsAsync.requireValue);
    }

    final isSaving = ref.watch(intentControllerProvider).isLoading;
    final skillsAsync = ref.watch(allSkillsProvider);
    final config = intentTypeConfig(_intentType);
    final skills = skillsAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: HomeStyle.background,
        toolbarHeight: 64,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_isEditing ? 'Edit Intent' : 'Create Intent',
                style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 2),
            const Text('Tell the community what you are looking to accomplish.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: HomeStyle.textSecondary),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FormSectionCard(
                  icon: Icons.flag_outlined,
                  title: 'Intent type',
                  subtitle: 'What are you trying to accomplish right now?',
                  children: [
                    Material(
                      key: _intentFieldKey,
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _openIntentTypeMenu,
                        child: InputDecorator(
                          decoration: darkInputDecoration('Intent'),
                          child: Row(
                            children: [
                              Icon(config.icon, size: 18, color: HomeStyle.purple),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_intentType.label,
                                    style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w600)),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: HomeStyle.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.info_outline,
                  title: 'Basic information',
                  children: [
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Title', hint: 'e.g. AI Powered Study Platform'),
                      validator: (v) => Validators.required(v, fieldName: 'Title'),
                    ),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      maxLength: 500,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Description', hint: 'Give a clear and detailed description...')
                          .copyWith(counterStyle: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11)),
                      validator: (v) => Validators.required(v, fieldName: 'Description'),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: config.icon,
                  title: config.sectionTitle,
                  subtitle: 'Specific to "${_intentType.label}"',
                  children: [for (final field in config.fields) _buildDynField(field)],
                ),
                FormSectionCard(
                  icon: Icons.handshake_outlined,
                  title: 'Skills',
                  subtitle: 'Add skills you need and skills you can offer to get better matches.',
                  children: [
                    const Text('Skills I need *',
                        style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    skillsAsync.when(
                      data: (skills) => MultiSelectChips(
                        options: [for (final s in skills) s.name],
                        selected: {for (final s in skills) if (_skillsNeeded.contains(s.id)) s.name},
                        onChanged: (namesSelected) => setState(() {
                          _skillsNeeded
                            ..clear()
                            ..addAll([for (final s in skills) if (namesSelected.contains(s.name)) s.id]);
                        }),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Could not load skills', style: TextStyle(color: HomeStyle.textSecondary)),
                    ),
                    const SizedBox(height: 14),
                    const Text('Skills I can offer *',
                        style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    skillsAsync.when(
                      data: (skills) => MultiSelectChips(
                        options: [for (final s in skills) s.name],
                        selected: {for (final s in skills) if (_skillsOffered.contains(s.id)) s.name},
                        onChanged: (namesSelected) => setState(() {
                          _skillsOffered
                            ..clear()
                            ..addAll([for (final s in skills) if (namesSelected.contains(s.name)) s.id]);
                        }),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.tune_outlined,
                  title: 'Preferences',
                  subtitle: 'Help others understand your experience and working style.',
                  children: [
                    _FieldRow(children: [
                      DropdownButtonFormField<ExperienceLevel>(
                        isExpanded: true,
                        initialValue: _experienceLevel,
                        dropdownColor: HomeStyle.cardBase,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Experience level'),
                        items: [for (final l in ExperienceLevel.values) DropdownMenuItem(value: l, child: Text(l.label))],
                        onChanged: (v) => setState(() => _experienceLevel = v ?? _experienceLevel),
                      ),
                      TextFormField(
                        controller: _preferredRoleController,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Preferred role (optional)', hint: 'Any role'),
                      ),
                    ]),
                    _FieldRow(children: [
                      TextFormField(
                        controller: _locationController,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Location preference (optional)'),
                      ),
                      DropdownButtonFormField<WorkMode?>(
                        isExpanded: true,
                        initialValue: _workMode,
                        dropdownColor: HomeStyle.cardBase,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Remote / in-person'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('No preference')),
                          for (final m in WorkMode.values) DropdownMenuItem(value: m, child: Text(m.label)),
                        ],
                        onChanged: (v) => setState(() => _workMode = v),
                      ),
                    ]),
                    TextFormField(
                      controller: _commitmentController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Commitment level (optional)', hint: 'e.g. 10 hrs/week'),
                    ),
                  ],
                ),
                CollapsibleFormSection(
                  icon: Icons.add_link_outlined,
                  title: 'Additional details',
                  subtitle: 'Optional — add links or notes if they help others understand your Intent.',
                  children: [
                    TextFormField(
                      controller: _githubController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('GitHub (optional)'),
                    ),
                    TextFormField(
                      controller: _figmaController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Figma / design link (optional)'),
                    ),
                    TextFormField(
                      controller: _portfolioController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Portfolio (optional)'),
                    ),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Additional notes (optional)'),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.visibility_outlined,
                  title: 'Visibility & expiry',
                  subtitle: 'Control who can see your Intent and how long it stays active.',
                  children: [
                    _FieldRow(children: [
                      _SelectableOptionCard(
                        icon: Icons.public_rounded,
                        title: 'Public',
                        subtitle: 'Visible to everyone',
                        selected: _visibility == IntentVisibility.public,
                        onTap: () => setState(() => _visibility = IntentVisibility.public),
                      ),
                      _SelectableOptionCard(
                        icon: Icons.group_outlined,
                        title: 'Connections only',
                        subtitle: 'Visible to your connections',
                        selected: _visibility == IntentVisibility.connectionsOnly,
                        onTap: () => setState(() => _visibility = IntentVisibility.connectionsOnly),
                      ),
                    ]),
                    const Text('Expires in', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final d in _durations)
                          ChoiceChip(
                            label: Text(d.label),
                            selected: _duration == d,
                            onSelected: (_) async {
                              setState(() => _duration = d);
                              if (d.days == null) await _pickCustomExpiry();
                            },
                          ),
                      ],
                    ),
                    if (_duration.days == null && _customExpiry != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Expires ${_customExpiry!.toLocal()}'.split(' ').first,
                            style: const TextStyle(color: HomeStyle.textSecondary)),
                      ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.remove_red_eye_outlined,
                  title: 'Preview',
                  subtitle: 'This is how your Intent will appear to others.',
                  children: [
                    Container(
                      constraints: const BoxConstraints(minHeight: 120),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: _titleController.text.trim().isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('Fill in the form above to see a live preview.',
                                  style: TextStyle(color: HomeStyle.textSecondary)),
                            )
                          : IntentDetailView(
                              intent: _buildPreviewIntent(skills),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: HomeStyle.background,
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isSaving ? null : _submit,
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEditing ? 'Save changes' : 'Post Intent'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays [children] out as a row of equal-width fields on wider screens and
/// stacks them on narrow phones — the "two-column on desktop, one column on
/// mobile" rule for Preferences/Visibility.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (children.length == 1 || constraints.maxWidth < 420) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Expanded(child: children[i]),
            if (i != children.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    });
  }
}

class _SelectableOptionCard extends StatelessWidget {
  const _SelectableOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? HomeStyle.purple.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? HomeStyle.purple : Colors.white.withValues(alpha: 0.10), width: selected ? 1.4 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: selected ? HomeStyle.purple : HomeStyle.textSecondary),
              const SizedBox(height: 8),
              Text(title,
                  style: TextStyle(
                      color: selected ? HomeStyle.textPrimary : HomeStyle.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntentTypeMenuRow extends StatelessWidget {
  const _IntentTypeMenuRow({required this.type, required this.selected});

  final IntentType type;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = intentTypeConfig(type).icon;
    return Container(
      color: selected ? HomeStyle.purple.withValues(alpha: 0.14) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: selected ? HomeStyle.purple : HomeStyle.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(type.label,
                    style: TextStyle(
                        color: HomeStyle.textPrimary, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 1),
                Text(type.shortDescription, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5)),
              ],
            ),
          ),
          if (selected) const Icon(Icons.check_rounded, color: HomeStyle.purple, size: 18),
        ],
      ),
    );
  }
}
