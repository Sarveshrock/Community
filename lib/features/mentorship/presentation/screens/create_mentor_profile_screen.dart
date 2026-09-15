import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/multi_select_chips.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/mentor_providers.dart';

const _currencies = ['USD', 'INR', 'EUR', 'GBP'];

/// The single Create/Edit Mentor Profile screen — mirrors the Jobs/Events
/// sectioned-builder pattern (FormSectionCard/MultiSelectChips/
/// darkInputDecoration) rather than introducing a new wizard/stepper UI.
/// Doubles as Edit when the caller already has a mentor profile
/// ([myMentorProfileProvider] non-null) — same screen, same components,
/// no separate edit form.
class CreateMentorProfileScreen extends ConsumerStatefulWidget {
  const CreateMentorProfileScreen({super.key});

  @override
  ConsumerState<CreateMentorProfileScreen> createState() => _CreateMentorProfileScreenState();
}

class _CreateMentorProfileScreenState extends ConsumerState<CreateMentorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _headlineController = TextEditingController();
  final _bioController = TextEditingController();
  final _customTopicController = TextEditingController();
  final _priceController = TextEditingController();
  final _sessionDurationController = TextEditingController(text: '30');
  final _availabilityController = TextEditingController();

  bool _initialized = false;
  bool _isEditing = false;
  bool _reviewing = false;

  final Set<String> _expertise = {};
  final Set<String> _topics = {};
  String _mentorshipType = '1:1';
  final Set<String> _communicationModes = {};
  String _pricingType = 'free';
  String _currency = 'USD';
  bool _acceptingMentees = true;

  @override
  void dispose() {
    _headlineController.dispose();
    _bioController.dispose();
    _customTopicController.dispose();
    _priceController.dispose();
    _sessionDurationController.dispose();
    _availabilityController.dispose();
    super.dispose();
  }

  void _hydrate(Mentor mentor) {
    if (_initialized) return;
    _isEditing = true;
    _expertise
      ..clear()
      ..addAll(mentor.expertise);
    _topics
      ..clear()
      ..addAll(mentor.topics);
    _headlineController.text = mentor.headline ?? '';
    _bioController.text = mentor.bio ?? '';
    _mentorshipType = mentor.mentorshipType ?? '1:1';
    _communicationModes
      ..clear()
      ..addAll(mentor.communicationModes);
    _pricingType = mentor.pricingType;
    _priceController.text = mentor.price?.toStringAsFixed(0) ?? '';
    _currency = mentor.currency ?? 'USD';
    _sessionDurationController.text = mentor.sessionDurationMinutes.toString();
    _availabilityController.text = mentor.availabilityNote ?? '';
    _acceptingMentees = mentor.available;
    _initialized = true;
  }

  void _addCustomTopic() {
    final text = _customTopicController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _topics.add(text);
      _customTopicController.clear();
    });
  }

  bool _validate() {
    if (!_formKey.currentState!.validate()) return false;
    if (_expertise.isEmpty) {
      context.showSnack('Select at least one thing you can mentor on', isError: true);
      return false;
    }
    if (_pricingType == 'paid' && num.tryParse(_priceController.text.trim()) == null) {
      context.showSnack('Enter a session price, or switch to Free', isError: true);
      return false;
    }
    return true;
  }

  Map<String, dynamic> _buildData() {
    return {
      'expertise': _expertise.toList(),
      'topics': _topics.toList(),
      'headline': _headlineController.text.trim().isEmpty ? null : _headlineController.text.trim(),
      'bio': _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      'mentorship_type': _mentorshipType,
      'communication_modes': _communicationModes.toList(),
      'pricing_type': _pricingType,
      'price': _pricingType == 'paid' ? num.tryParse(_priceController.text.trim()) : null,
      'currency': _pricingType == 'paid' ? _currency : null,
      'session_duration_minutes': int.tryParse(_sessionDurationController.text.trim()) ?? 30,
      'availability_note':
          _availabilityController.text.trim().isEmpty ? null : _availabilityController.text.trim(),
      'available': _acceptingMentees,
    };
  }

  Future<void> _submit() async {
    final ok = await ref.read(mentorControllerProvider.notifier).becomeMentor(_buildData());
    if (!mounted) return;
    if (ok) {
      context.showSnack(_isEditing ? 'Mentor profile updated' : 'You\'re now a mentor!');
      context.pop();
    } else {
      context.showSnack('Could not save your mentor profile', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mentorAsync = ref.watch(myMentorProfileProvider);
    final profileAsync = ref.watch(myProfileProvider);

    if (mentorAsync.isLoading || profileAsync.isLoading) {
      return const Scaffold(backgroundColor: HomeStyle.background, body: LoadingState());
    }
    if (mentorAsync.hasError) {
      return Scaffold(backgroundColor: HomeStyle.background, body: ErrorState(message: mentorAsync.error.toString()));
    }
    if (mentorAsync.value != null) _hydrate(mentorAsync.value!);

    if (_reviewing) {
      return _PreviewScreen(
        profile: profileAsync.valueOrNull,
        headline: _headlineController.text.trim(),
        bio: _bioController.text.trim(),
        expertise: _expertise.toList(),
        topics: _topics.toList(),
        mentorshipType: _mentorshipType,
        communicationModes: _communicationModes.toList(),
        pricingType: _pricingType,
        price: num.tryParse(_priceController.text.trim()),
        currency: _currency,
        sessionDurationMinutes: int.tryParse(_sessionDurationController.text.trim()) ?? 30,
        availabilityNote: _availabilityController.text.trim(),
        acceptingMentees: _acceptingMentees,
        isEditing: _isEditing,
        onBack: () => setState(() => _reviewing = false),
        onConfirm: _submit,
      );
    }

    return _buildForm(context, profileAsync.valueOrNull);
  }

  Widget _buildForm(BuildContext context, Profile? profile) {
    final skillsAsync = ref.watch(allSkillsProvider);
    final experiencesAsync = ref.watch(myExperiencesProvider);
    final educationAsync = ref.watch(myEducationProvider);
    final isSaving = ref.watch(mentorControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: HomeStyle.background,
        title: Text(_isEditing ? 'Edit Mentorship' : 'Become a Mentor',
            style: const TextStyle(color: HomeStyle.textPrimary)),
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
                  icon: Icons.psychology_outlined,
                  title: 'What can you mentor?',
                  subtitle: 'Pick the skills and topics you can guide others on',
                  children: [
                    skillsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Could not load skills'),
                      data: (skills) => MultiSelectChips(
                        options: {...skills.map((s) => s.name), ..._expertise}.toList(),
                        selected: _expertise,
                        onChanged: (v) => setState(() {
                          _expertise
                            ..clear()
                            ..addAll(v);
                        }),
                      ),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.support_agent_outlined,
                  title: 'What can you help with?',
                  children: [
                    MultiSelectChips(
                      options: {...kMentorshipTopics, ..._topics}.toList(),
                      selected: _topics,
                      onChanged: (v) => setState(() {
                        _topics
                          ..clear()
                          ..addAll(v);
                      }),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customTopicController,
                            style: const TextStyle(color: HomeStyle.textPrimary),
                            decoration: darkInputDecoration('Add another'),
                            onSubmitted: (_) => _addCustomTopic(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(onPressed: _addCustomTopic, icon: const Icon(Icons.add_rounded)),
                      ],
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.edit_note_outlined,
                  title: 'Mentor introduction',
                  subtitle: 'Separate from your regular Communeo bio',
                  children: [
                    TextFormField(
                      controller: _headlineController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Mentorship headline',
                          hint: 'e.g. Helping developers become better backend engineers'),
                      validator: (v) => Validators.required(v, fieldName: 'Headline'),
                    ),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 4,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('About your mentorship',
                          hint: 'What do you help mentees with, and how?'),
                      validator: (v) => Validators.required(v, fieldName: 'About your mentorship'),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.badge_outlined,
                  title: 'Your background',
                  subtitle: 'Pulled from your Communeo profile',
                  children: [
                    if (profile?.currentRole != null) _ReadOnlyRow(label: 'Role', value: profile!.headline),
                    _ReadOnlyRow(
                        label: 'Experience', value: Formatters.experienceFromMonths(profile?.totalItExperienceMonths ?? 0)),
                    if (profile?.skills.isNotEmpty ?? false)
                      _ReadOnlyRow(label: 'Skills', value: profile!.skills.map((s) => s.skill.name).join(', ')),
                    if (educationAsync.valueOrNull?.isNotEmpty ?? false)
                      _ReadOnlyRow(label: 'Education', value: educationAsync.value!.first.institution),
                    if (experiencesAsync.valueOrNull?.isNotEmpty ?? false)
                      _ReadOnlyRow(
                          label: 'Latest role',
                          value: '${experiencesAsync.value!.first.role} at ${experiencesAsync.value!.first.companyName}'),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.groups_outlined,
                  title: 'Mentorship format',
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _mentorshipType,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('What type of mentorship do you provide?'),
                      items: [for (final t in kMentorshipTypes) DropdownMenuItem(value: t, child: Text(t))],
                      onChanged: (v) => setState(() => _mentorshipType = v ?? _mentorshipType),
                    ),
                    const SizedBox(height: 4),
                    const Text('How do you mentor?', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    MultiSelectChips(
                      options: [for (final m in CommunicationMode.values) CommunicationMode.label(m)],
                      selected: {for (final m in _communicationModes) CommunicationMode.label(m)},
                      onChanged: (labels) => setState(() {
                        _communicationModes
                          ..clear()
                          ..addAll([
                            for (final m in CommunicationMode.values)
                              if (labels.contains(CommunicationMode.label(m))) m,
                          ]);
                      }),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.payments_outlined,
                  title: 'Pricing',
                  subtitle: 'How do you want to provide mentorship?',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _PricingOption(
                            label: 'Free',
                            selected: _pricingType == 'free',
                            onTap: () => setState(() => _pricingType = 'free'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PricingOption(
                            label: 'Paid',
                            selected: _pricingType == 'paid',
                            onTap: () => setState(() => _pricingType = 'paid'),
                          ),
                        ),
                      ],
                    ),
                    if (_pricingType == 'paid') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: HomeStyle.textPrimary),
                              decoration: darkInputDecoration('Session price'),
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
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _sessionDurationController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Session duration (minutes)'),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.event_available_outlined,
                  title: 'Availability',
                  children: [
                    TextFormField(
                      controller: _availabilityController,
                      maxLines: 3,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Availability (optional)',
                          hint: 'e.g. Mon & Wed 7-9 PM, Sat 10 AM-1 PM, IST'),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Accepting new mentees', style: TextStyle(color: HomeStyle.textPrimary)),
                      subtitle: Text(
                        _acceptingMentees
                            ? 'You\'ll show up in mentor search'
                            : 'Your profile is kept, but hidden from mentor search until you turn this back on',
                        style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12),
                      ),
                      value: _acceptingMentees,
                      onChanged: (v) => setState(() => _acceptingMentees = v),
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

class _PricingOption extends StatelessWidget {
  const _PricingOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HomeStyle.purple.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? HomeStyle.purple : Colors.white.withValues(alpha: 0.10)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? HomeStyle.purple : HomeStyle.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5)),
        ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: HomeStyle.textSecondary, height: 1.4),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _PreviewScreen extends StatelessWidget {
  const _PreviewScreen({
    required this.profile,
    required this.headline,
    required this.bio,
    required this.expertise,
    required this.topics,
    required this.mentorshipType,
    required this.communicationModes,
    required this.pricingType,
    required this.price,
    required this.currency,
    required this.sessionDurationMinutes,
    required this.availabilityNote,
    required this.acceptingMentees,
    required this.isEditing,
    required this.onBack,
    required this.onConfirm,
  });

  final Profile? profile;
  final String headline;
  final String bio;
  final List<String> expertise;
  final List<String> topics;
  final String mentorshipType;
  final List<String> communicationModes;
  final String pricingType;
  final num? price;
  final String currency;
  final int sessionDurationMinutes;
  final String availabilityNote;
  final bool acceptingMentees;
  final bool isEditing;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: HomeStyle.background,
        title: const Text('Preview', style: TextStyle(color: HomeStyle.textPrimary)),
        iconTheme: const IconThemeData(color: HomeStyle.textPrimary),
      ),
      body: ResponsiveCenter(
        maxWidth: 560,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: HomeStyle.cardBase,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UserAvatar(avatarUrl: profile?.avatarUrl, name: profile?.displayName ?? '?', radius: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(profile?.displayName ?? 'You',
                                  style: const TextStyle(
                                      color: HomeStyle.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                              if (profile?.currentRole != null)
                                Text(profile!.headline, style: const TextStyle(color: HomeStyle.blue, fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (headline.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(headline,
                          style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 14.5)),
                    ],
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(bio, style: const TextStyle(color: HomeStyle.textSecondary, height: 1.4)),
                    ],
                    if (expertise.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text('Expertise', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5)),
                      const SizedBox(height: 6),
                      _ChipWrap(items: expertise, accent: HomeStyle.purple),
                    ],
                    if (topics.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text('Can help with', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5)),
                      const SizedBox(height: 6),
                      _ChipWrap(items: topics, accent: HomeStyle.cyan),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip('$mentorshipType mentorship'),
                        for (final m in communicationModes) _InfoChip(CommunicationMode.label(m)),
                        _InfoChip(pricingType == 'free' ? 'Free' : '$price $currency / session'),
                        _InfoChip('$sessionDurationMinutes min sessions'),
                        _InfoChip(acceptingMentees ? 'Accepting mentees' : 'Not accepting mentees'),
                      ],
                    ),
                    if (availabilityNote.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text('Availability', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5)),
                      const SizedBox(height: 4),
                      Text(availabilityNote, style: const TextStyle(color: HomeStyle.textPrimary, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: onBack, child: const Text('Back to edit')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: onConfirm,
                        child: Text(isEditing ? 'Save changes' : 'Become a Mentor'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.items, required this.accent});
  final List<String> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Text(item, style: TextStyle(fontSize: 12.5, color: accent, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11.5, color: HomeStyle.textSecondary, fontWeight: FontWeight.w600)),
    );
  }
}
