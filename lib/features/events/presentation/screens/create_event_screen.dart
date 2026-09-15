import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../profile/presentation/providers/profile_providers.dart' show allSkillsProvider;
import '../providers/event_providers.dart';
import '../widgets/agenda_editor.dart';
import '../widgets/event_detail_view.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../../core/widgets/multi_select_chips.dart';
import '../widgets/speaker_editor.dart';

const _modes = ['online', 'offline', 'hybrid'];
const _whatToBringOptions = ['Laptop', 'ID proof', 'Own equipment', 'Required software', 'Other'];
const _benefitOptions = [
  'Certificate',
  'Goodies',
  'Mentorship',
  'Networking',
  'Food',
  'Prizes',
  'Learning experience',
];
const _skillLevels = ['Beginner', 'Intermediate', 'Advanced', 'All levels'];
const _currencies = ['INR', 'USD', 'EUR', 'GBP'];
const _timezones = [
  'UTC',
  'Asia/Kolkata',
  'Asia/Singapore',
  'Asia/Dubai',
  'Europe/London',
  'America/New_York',
  'America/Los_Angeles',
  'Australia/Sydney',
];

/// The Event Builder. A single scrollable, sectioned form rather than a
/// hard multi-page wizard (spec: "use sections... do not overwhelm the
/// organizer") — Basics/Date & Time/Location/Agenda/Speakers stay always
/// visible, while the less-often-needed Audience & Registration/Pricing/
/// Requirements & Benefits fields live inside a collapsed-by-default
/// "Advanced settings" section. Also doubles as the Edit Event screen when
/// [editEventId] is set, prefilling from the existing event.
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key, this.editEventId});

  final String? editEventId;

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _shortDescController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _meetingPlatformController = TextEditingController();
  final _meetingUrlController = TextEditingController();
  final _joiningInstructionsController = TextEditingController();
  final _venueNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  final _priceController = TextEditingController();
  final _prerequisitesController = TextEditingController();
  final _requiredSoftwareController = TextEditingController();

  bool _initialized = false;
  bool _uploadingCover = false;
  Uint8List? _coverBytes;
  String? _coverFileExt;
  String? _existingCoverUrl;

  String _eventType = 'community_event';
  String _mode = 'online';
  final Set<String> _tagSkillIds = {};
  DateTime _startDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _isAllDay = false;
  String _timezone = 'Asia/Kolkata';
  bool _registrationRequired = true;
  DateTime? _registrationDeadline;
  EventVisibility _visibility = EventVisibility.public;
  final Set<String> _audience = {};
  bool _isFree = true;
  String _currency = 'INR';
  final Set<String> _whatToBring = {};
  final Set<String> _benefits = {};
  String? _skillLevel;
  List<EventAgendaItem> _agenda = [];
  List<EventSpeaker> _speakers = [];

  bool get _isEditing => widget.editEventId != null;

  DateTime get _startsAt =>
      DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime.hour, _startTime.minute);
  DateTime? get _endsAt => _endDate == null
      ? null
      : DateTime(_endDate!.year, _endDate!.month, _endDate!.day,
          (_endTime ?? _startTime).hour, (_endTime ?? _startTime).minute);

  @override
  void dispose() {
    for (final c in [
      _titleController,
      _shortDescController,
      _descriptionController,
      _meetingPlatformController,
      _meetingUrlController,
      _joiningInstructionsController,
      _venueNameController,
      _addressController,
      _cityController,
      _stateController,
      _pincodeController,
      _maxParticipantsController,
      _priceController,
      _prerequisitesController,
      _requiredSoftwareController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(CommunityEvent event, List<EventAgendaItem> agenda, List<EventSpeaker> speakers) {
    if (_initialized) return;
    _titleController.text = event.title;
    _shortDescController.text = event.shortDescription ?? '';
    _descriptionController.text = event.description ?? '';
    _meetingPlatformController.text = event.meetingPlatform ?? '';
    _meetingUrlController.text = event.meetingUrl ?? '';
    _joiningInstructionsController.text = event.joiningInstructions ?? '';
    _venueNameController.text = event.venueName ?? '';
    _addressController.text = event.address ?? '';
    _cityController.text = event.city ?? '';
    _stateController.text = event.state ?? '';
    _pincodeController.text = event.pincode ?? '';
    _maxParticipantsController.text = event.maxParticipants?.toString() ?? '';
    _priceController.text = event.price?.toStringAsFixed(0) ?? '';
    _prerequisitesController.text = event.prerequisites ?? '';
    _requiredSoftwareController.text = event.requiredSoftware.join(', ');
    _eventType = event.eventType;
    _mode = event.mode;
    _existingCoverUrl = event.coverImageUrl;
    _startDate = event.startsAt.toLocal();
    _startTime = TimeOfDay.fromDateTime(event.startsAt.toLocal());
    if (event.endsAt != null) {
      _endDate = event.endsAt!.toLocal();
      _endTime = TimeOfDay.fromDateTime(event.endsAt!.toLocal());
    }
    _isAllDay = event.isAllDay;
    _timezone = event.timezone;
    _registrationRequired = event.registrationRequired;
    _registrationDeadline = event.registrationDeadline?.toLocal();
    _visibility = event.visibility;
    _audience
      ..clear()
      ..addAll(event.audience);
    _isFree = event.isFree;
    _currency = event.currency;
    _whatToBring
      ..clear()
      ..addAll(event.whatToBring);
    _benefits
      ..clear()
      ..addAll(event.benefits);
    _skillLevel = event.skillLevel;
    _agenda = agenda;
    _speakers = speakers;
    _initialized = true;
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _coverBytes = bytes;
      _coverFileExt = file.name.split('.').last;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null) return;
    setState(() => isStart ? _startDate = date : _endDate = date);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final time = await showTimePicker(context: context, initialTime: isStart ? _startTime : (_endTime ?? _startTime));
    if (time == null) return;
    setState(() => isStart ? _startTime = time : _endTime = time);
  }

  Future<void> _pickRegistrationDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _registrationDeadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: _startDate,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_registrationDeadline ?? DateTime.now()));
    if (time == null) return;
    setState(() => _registrationDeadline = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Map<String, dynamic> _buildEventData() {
    return {
      'title': _titleController.text.trim(),
      'short_description': _shortDescController.text.trim().isEmpty ? null : _shortDescController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      'event_type': _eventType,
      'mode': _mode,
      'starts_at': _startsAt.toIso8601String(),
      'ends_at': _endsAt?.toIso8601String(),
      'is_all_day': _isAllDay,
      'timezone': _timezone,
      if (_mode != 'offline') 'meeting_platform':
          _meetingPlatformController.text.trim().isEmpty ? null : _meetingPlatformController.text.trim(),
      if (_mode != 'offline') 'meeting_url':
          _meetingUrlController.text.trim().isEmpty ? null : _meetingUrlController.text.trim(),
      if (_mode != 'offline') 'joining_instructions':
          _joiningInstructionsController.text.trim().isEmpty ? null : _joiningInstructionsController.text.trim(),
      if (_mode != 'online') 'venue_name':
          _venueNameController.text.trim().isEmpty ? null : _venueNameController.text.trim(),
      if (_mode != 'online') 'address':
          _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      if (_mode != 'online') 'city': _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      if (_mode != 'online') 'state': _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
      if (_mode != 'online') 'pincode':
          _pincodeController.text.trim().isEmpty ? null : _pincodeController.text.trim(),
      'max_participants':
          _maxParticipantsController.text.trim().isEmpty ? null : int.tryParse(_maxParticipantsController.text.trim()),
      'registration_required': _registrationRequired,
      'registration_deadline': _registrationDeadline?.toIso8601String(),
      'visibility': _visibility.value,
      'audience': _audience.toList(),
      'is_free': _isFree,
      'price': _isFree ? null : double.tryParse(_priceController.text.trim()),
      'currency': _currency,
      'what_to_bring': _whatToBring.toList(),
      'prerequisites': _prerequisitesController.text.trim().isEmpty ? null : _prerequisitesController.text.trim(),
      'benefits': _benefits.toList(),
      'skill_level': _eventType == 'workshop' ? _skillLevel : null,
      'required_software': _eventType == 'workshop'
          ? _requiredSoftwareController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : <String>[],
    };
  }

  CommunityEvent _previewEvent() {
    return CommunityEvent(
      id: widget.editEventId ?? 'preview',
      hostId: '',
      title: _titleController.text.trim().isEmpty ? 'Untitled event' : _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      eventType: _eventType,
      mode: _mode,
      startsAt: _startsAt,
      endsAt: _endsAt,
      isAllDay: _isAllDay,
      timezone: _timezone,
      coverImageUrl: _existingCoverUrl,
      meetingPlatform: _meetingPlatformController.text.trim().isEmpty ? null : _meetingPlatformController.text.trim(),
      meetingUrl: _meetingUrlController.text.trim().isEmpty ? null : _meetingUrlController.text.trim(),
      venueName: _venueNameController.text.trim().isEmpty ? null : _venueNameController.text.trim(),
      city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      state: _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
      maxParticipants: int.tryParse(_maxParticipantsController.text.trim()),
      registrationRequired: _registrationRequired,
      registrationDeadline: _registrationDeadline,
      visibility: _visibility,
      audience: _audience.toList(),
      isFree: _isFree,
      price: double.tryParse(_priceController.text.trim()),
      currency: _currency,
      whatToBring: _whatToBring.toList(),
      prerequisites: _prerequisitesController.text.trim().isEmpty ? null : _prerequisitesController.text.trim(),
      benefits: _benefits.toList(),
    );
  }

  void _openPreview() {
    if (_titleController.text.trim().isEmpty) {
      context.showSnack('Add a title before previewing', isError: true);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: HomeStyle.background,
        body: SafeArea(
          child: Stack(
            children: [
              EventDetailView(
                event: _previewEvent(),
                agenda: _agenda,
                speakers: _speakers,
                coverImageBytesPreview: _coverBytes != null ? MemoryImage(_coverBytes!) : null,
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                        width: 40, height: 40, child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(eventControllerProvider.notifier);
    final skillIds = _tagSkillIds.toList();

    if (_isEditing) {
      final ok = await controller.updateEvent(
        widget.editEventId!,
        _buildEventData(),
        tagSkillIds: skillIds,
        agendaItems: _agenda,
        speakers: _speakers,
      );
      if (!mounted) return;
      if (ok) {
        context.showSnack('Event updated');
        context.pop();
      } else {
        context.showSnack('Could not update event', isError: true);
      }
      return;
    }

    final created = await controller.createEvent(
      _buildEventData(),
      tagSkillIds: skillIds,
      agendaItems: _agenda,
      speakers: _speakers,
    );
    if (!mounted) return;
    if (created == null) {
      context.showSnack('Could not create event', isError: true);
      return;
    }
    if (_coverBytes != null && _coverFileExt != null) {
      setState(() => _uploadingCover = true);
      final url = await controller.uploadCoverImage(created.id, _coverBytes!, _coverFileExt!);
      if (url != null) {
        await ref.read(eventRepositoryProvider).updateEvent(created.id, {'cover_image_url': url});
      }
      if (mounted) setState(() => _uploadingCover = false);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      final eventAsync = ref.watch(eventDetailProvider(widget.editEventId!));
      final agendaAsync = ref.watch(eventAgendaProvider(widget.editEventId!));
      final speakersAsync = ref.watch(eventSpeakersProvider(widget.editEventId!));
      if (eventAsync.isLoading || agendaAsync.isLoading || speakersAsync.isLoading) {
        return const Scaffold(backgroundColor: HomeStyle.background, body: LoadingState());
      }
      if (eventAsync.hasError) {
        return Scaffold(
            backgroundColor: HomeStyle.background,
            body: ErrorState(message: eventAsync.error.toString()));
      }
      _hydrate(eventAsync.value!, agendaAsync.valueOrNull ?? [], speakersAsync.valueOrNull ?? []);
    }
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) {
    final isSaving = ref.watch(eventControllerProvider).isLoading || _uploadingCover;
    final skillsAsync = ref.watch(allSkillsProvider);

    return Scaffold(
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: HomeStyle.background,
        title: Text(_isEditing ? 'Edit Event' : 'Create Event', style: const TextStyle(color: HomeStyle.textPrimary)),
        iconTheme: const IconThemeData(color: HomeStyle.textPrimary),
        actions: [
          TextButton(
            onPressed: _openPreview,
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
                FormSectionCard(
                  icon: Icons.info_outline_rounded,
                  title: 'Basics',
                  children: [
                    _CoverPicker(
                      bytes: _coverBytes,
                      existingUrl: _existingCoverUrl,
                      onTap: _pickCoverImage,
                    ),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Event title'),
                      validator: (v) => Validators.required(v, fieldName: 'Title'),
                    ),
                    TextFormField(
                      controller: _shortDescController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Short description', hint: 'One line for cards/search'),
                    ),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Detailed description'),
                    ),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _eventType,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Event category'),
                      items: [
                        for (final t in kEventTypes) DropdownMenuItem(value: t, child: Text(eventTypeLabel(t))),
                      ],
                      onChanged: (v) => setState(() => _eventType = v ?? _eventType),
                    ),
                    if (_eventType == 'hackathon') const _HackathonNotice(),
                    const Text('Tags/topics', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    skillsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Could not load tags'),
                      data: (skills) => MultiSelectChips(
                        options: [for (final s in skills) s.name],
                        selected: {
                          for (final s in skills)
                            if (_tagSkillIds.contains(s.id)) s.name,
                        },
                        onChanged: (selectedNames) {
                          setState(() {
                            _tagSkillIds
                              ..clear()
                              ..addAll([
                                for (final s in skills)
                                  if (selectedNames.contains(s.name)) s.id,
                              ]);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.event_outlined,
                  title: 'Date & Time',
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('All-day event', style: TextStyle(color: HomeStyle.textPrimary)),
                      value: _isAllDay,
                      onChanged: (v) => setState(() => _isAllDay = v),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickDate(isStart: true),
                            child: Text('Start: ${_startDate.month}/${_startDate.day}/${_startDate.year}'),
                          ),
                        ),
                        if (!_isAllDay) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _pickTime(isStart: true),
                              child: Text(_startTime.format(context)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickDate(isStart: false),
                            child: Text(_endDate == null
                                ? 'End date (optional)'
                                : '${_endDate!.month}/${_endDate!.day}/${_endDate!.year}'),
                          ),
                        ),
                        if (!_isAllDay && _endDate != null) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _pickTime(isStart: false),
                              child: Text(_endTime?.format(context) ?? 'End time'),
                            ),
                          ),
                        ],
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _timezone,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Timezone'),
                      items: [for (final tz in _timezones) DropdownMenuItem(value: tz, child: Text(tz))],
                      onChanged: (v) => setState(() => _timezone = v ?? _timezone),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.place_outlined,
                  title: 'Location',
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _mode,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Mode'),
                      items: [
                        for (final m in _modes)
                          DropdownMenuItem(value: m, child: Text(m[0].toUpperCase() + m.substring(1))),
                      ],
                      onChanged: (v) => setState(() => _mode = v ?? _mode),
                    ),
                    if (_mode != 'offline') ...[
                      TextFormField(
                        controller: _meetingPlatformController,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Platform', hint: 'Zoom, Google Meet, Discord...'),
                      ),
                      TextFormField(
                        controller: _meetingUrlController,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Meeting URL'),
                        validator: Validators.url,
                      ),
                      TextFormField(
                        controller: _joiningInstructionsController,
                        maxLines: 2,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Joining instructions (optional)'),
                      ),
                    ],
                    if (_mode != 'online') ...[
                      TextFormField(
                        controller: _venueNameController,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Venue name'),
                      ),
                      TextFormField(
                        controller: _addressController,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Address'),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cityController,
                              style: const TextStyle(color: HomeStyle.textPrimary),
                              decoration: darkInputDecoration('City'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _stateController,
                              style: const TextStyle(color: HomeStyle.textPrimary),
                              decoration: darkInputDecoration('State'),
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: _pincodeController,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Pincode'),
                      ),
                    ],
                  ],
                ),
                CollapsibleFormSection(
                  icon: Icons.tune_rounded,
                  title: 'Advanced settings',
                  subtitle: 'Audience, registration, pricing, requirements & benefits',
                  children: [
                    const Text('Audience & Registration',
                        style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                    TextFormField(
                      controller: _maxParticipantsController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Max participants (optional)'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Registration required', style: TextStyle(color: HomeStyle.textPrimary)),
                      value: _registrationRequired,
                      onChanged: (v) => setState(() => _registrationRequired = v),
                    ),
                    OutlinedButton(
                      onPressed: _pickRegistrationDeadline,
                      child: Text(_registrationDeadline == null
                          ? 'Registration deadline (optional)'
                          : 'Deadline: ${_registrationDeadline!.month}/${_registrationDeadline!.day}/${_registrationDeadline!.year}'),
                    ),
                    DropdownButtonFormField<EventVisibility>(
                      isExpanded: true,
                      initialValue: _visibility,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Visibility'),
                      items: [
                        for (final v in EventVisibility.values) DropdownMenuItem(value: v, child: Text(v.label)),
                      ],
                      onChanged: (v) => setState(() => _visibility = v ?? _visibility),
                    ),
                    const Text('Who should join?', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    MultiSelectChips(
                      options: kEventAudiences,
                      selected: _audience,
                      onChanged: (v) => setState(() {
                        _audience
                          ..clear()
                          ..addAll(v);
                      }),
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    const Text('Pricing',
                        style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('This is a free event', style: TextStyle(color: HomeStyle.textPrimary)),
                      value: _isFree,
                      onChanged: (v) => setState(() => _isFree = v),
                    ),
                    if (!_isFree) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: HomeStyle.textPrimary),
                              decoration: darkInputDecoration('Price'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                      isExpanded: true,
                              initialValue: _currency,
                              dropdownColor: HomeStyle.cardBase,
                              style: const TextStyle(color: HomeStyle.textPrimary),
                              decoration: darkInputDecoration('Currency'),
                              items: [for (final c in _currencies) DropdownMenuItem(value: c, child: Text(c))],
                              onChanged: (v) => setState(() => _currency = v ?? _currency),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Informational only — no payment is collected in-app yet.',
                        style: TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5),
                      ),
                    ],
                    const Divider(color: Colors.white12, height: 24),
                    const Text('Requirements & Benefits',
                        style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    const Text('What to bring', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    MultiSelectChips(
                      options: _whatToBringOptions,
                      selected: _whatToBring,
                      onChanged: (v) => setState(() {
                        _whatToBring
                          ..clear()
                          ..addAll(v);
                      }),
                    ),
                    TextFormField(
                      controller: _prerequisitesController,
                      maxLines: 2,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Prerequisites (optional)',
                          hint: 'e.g. Basic knowledge of Python is recommended.'),
                    ),
                    if (_eventType == 'workshop') ...[
                      DropdownButtonFormField<String>(
                      isExpanded: true,
                        initialValue: _skillLevel,
                        dropdownColor: HomeStyle.cardBase,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Skill level'),
                        items: [for (final l in _skillLevels) DropdownMenuItem(value: l, child: Text(l))],
                        onChanged: (v) => setState(() => _skillLevel = v),
                      ),
                      TextFormField(
                        controller: _requiredSoftwareController,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Required software', hint: 'Comma-separated'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text('What you\'ll get', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    MultiSelectChips(
                      options: _benefitOptions,
                      selected: _benefits,
                      onChanged: (v) => setState(() {
                        _benefits
                          ..clear()
                          ..addAll(v);
                      }),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.schedule_rounded,
                  title: 'Agenda',
                  subtitle: 'Optional — add sessions to give attendees a schedule',
                  children: [AgendaEditor(items: _agenda, onChanged: (v) => setState(() => _agenda = v))],
                ),
                FormSectionCard(
                  icon: Icons.groups_outlined,
                  title: 'Speakers & Hosts',
                  subtitle: 'Optional — link Communeo profiles or add external speakers',
                  children: [SpeakerEditor(speakers: _speakers, onChanged: (v) => setState(() => _speakers = v))],
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
                      onTap: isSaving ? null : _submit,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: HomeStyle.brandGradient,
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: HomeStyle.glow(HomeStyle.purple, opacity: 0.3),
                        ),
                        alignment: Alignment.center,
                        child: isSaving
                            ? const SizedBox(
                                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_isEditing ? 'Save changes' : 'Create event',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
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

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({required this.bytes, required this.existingUrl, required this.onTap});

  final Uint8List? bytes;
  final String? existingUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          image: bytes != null
              ? DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover)
              : existingUrl != null
                  ? DecorationImage(image: NetworkImage(existingUrl!), fit: BoxFit.cover)
                  : null,
        ),
        child: bytes == null && existingUrl == null
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, color: HomeStyle.textSecondary, size: 28),
                    SizedBox(height: 6),
                    Text('Add a cover image', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}

class _HackathonNotice extends StatelessWidget {
  const _HackathonNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomeStyle.blue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeStyle.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: HomeStyle.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('For team formation, tracks, and judging, use the dedicated Hackathons feature.',
                    style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12)),
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                  onPressed: () => context.push('/hackathons'),
                  child: const Text('Open Hackathons'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
