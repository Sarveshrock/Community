import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/models/user_type.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// Profile completion wizard (spec section 52: Splash -> Auth -> Check
/// profile -> Onboarding if incomplete -> Home). Only the primary
/// professional profile is collected here; Proof of Skills stays optional
/// and skippable per spec sections 5 & 16.
///
/// Visual-only redesign to match the dark `home_style.dart` system already
/// used by Settings/Jobs/Intents/AppIcon — this sat as the one plain
/// default-Material screen between the branded splash/sign-up and the
/// branded Home, which broke the first-run impression. No state, submit
/// logic, or field ever changed here — same 3 steps, same
/// `completeOnboarding` call, same data.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;
  static const _totalSteps = 3;

  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _companyController = TextEditingController();
  final _roleController = TextEditingController();
  final _goalsController = TextEditingController();
  UserType _userType = UserType.developer;
  double _experienceYears = 0;

  final Set<String> _selectedSkillIds = {};
  final Set<String> _selectedInterestIds = {};

  bool get _canContinueStep0 =>
      _nameController.text.trim().isNotEmpty &&
      _cityController.text.trim().isNotEmpty;

  void _next() {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      _pageController.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.previousPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _submit() async {
    final success =
        await ref.read(profileControllerProvider.notifier).completeOnboarding(
      profileChanges: {
        'full_name': _nameController.text.trim(),
        'city': _cityController.text.trim(),
        'primary_user_type': _userType.value,
        'current_company': _companyController.text.trim().isEmpty
            ? null
            : _companyController.text.trim(),
        'current_role': _roleController.text.trim().isEmpty
            ? null
            : _roleController.text.trim(),
        'career_goals': _goalsController.text.trim().isEmpty
            ? null
            : _goalsController.text.trim(),
        'total_it_experience_months': (_experienceYears * 12).round(),
      },
      skills: [
        for (final id in _selectedSkillIds) (id, ExperienceLevel.intermediate)
      ],
      interestIds: _selectedInterestIds.toList(),
    );
    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      context.showSnack('Could not save your profile. Please try again.',
          isError: true);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _companyController.dispose();
    _roleController.dispose();
    _goalsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(profileControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      if (_step > 0)
                        _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: _back)
                      else
                        const SizedBox(width: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (_step + 1) / _totalSteps,
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            valueColor: const AlwaysStoppedAnimation(HomeStyle.purple),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: ResponsiveCenter(
                    maxWidth: 560,
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _BasicInfoStep(
                          nameController: _nameController,
                          cityController: _cityController,
                          userType: _userType,
                          onUserTypeChanged: (t) => setState(() => _userType = t),
                          // Pre-existing gap, not introduced by this restyle:
                          // Continue's enabled state depends on
                          // _canContinueStep0, but typing alone never
                          // rebuilds this screen — nothing previously called
                          // setState on every keystroke, so Continue could
                          // stay stuck disabled even after both fields were
                          // filled, unless the user also touched a chip.
                          onFieldChanged: () => setState(() {}),
                        ),
                        _ProfessionalStep(
                          companyController: _companyController,
                          roleController: _roleController,
                          goalsController: _goalsController,
                          experienceYears: _experienceYears,
                          onExperienceChanged: (v) => setState(() => _experienceYears = v),
                        ),
                        _SkillsInterestsStep(
                          selectedSkillIds: _selectedSkillIds,
                          selectedInterestIds: _selectedInterestIds,
                          onSkillsChanged: () => setState(() {}),
                          onInterestsChanged: () => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  isSaving || (_step == 0 && !_canContinueStep0) ? null : _next,
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_step == _totalSteps - 1 ? 'Finish' : 'Continue'),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: HomeStyle.cardBase,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Icon(icon, size: 19, color: Colors.white),
        ),
      ),
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: HomeStyle.textPrimary, letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: HomeStyle.textSecondary, height: 1.4)),
      ],
    );
  }
}

class _DarkChip extends StatelessWidget {
  const _DarkChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? HomeStyle.purple.withValues(alpha: 0.20) : HomeStyle.cardBase,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? HomeStyle.purple : Colors.white.withValues(alpha: 0.10)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? HomeStyle.textPrimary : HomeStyle.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13)),
        ),
      ),
    );
  }
}

class _BasicInfoStep extends StatelessWidget {
  const _BasicInfoStep({
    required this.nameController,
    required this.cityController,
    required this.userType,
    required this.onUserTypeChanged,
    required this.onFieldChanged,
  });

  final TextEditingController nameController;
  final TextEditingController cityController;
  final UserType userType;
  final ValueChanged<UserType> onUserTypeChanged;

  /// Fired on every keystroke so the parent can re-evaluate whether Continue
  /// should be enabled — see the call site's comment for why this matters.
  final VoidCallback onFieldChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeading(
            title: 'Let\'s set up your profile',
            subtitle: 'This helps us find the right people and opportunities for you.',
          ),
          const SizedBox(height: 24),
          FormSectionCard(
            icon: Icons.person_outline,
            title: 'About you',
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: HomeStyle.textPrimary),
                decoration: darkInputDecoration('Full name', hint: 'e.g. Priya Sharma'),
                onChanged: (_) => onFieldChanged(),
              ),
              TextField(
                controller: cityController,
                style: const TextStyle(color: HomeStyle.textPrimary),
                decoration: darkInputDecoration('City'),
                onChanged: (_) => onFieldChanged(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('I am a…', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in UserType.values)
                _DarkChip(
                  label: type.label,
                  selected: userType == type,
                  onTap: () => onUserTypeChanged(type),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfessionalStep extends StatelessWidget {
  const _ProfessionalStep({
    required this.companyController,
    required this.roleController,
    required this.goalsController,
    required this.experienceYears,
    required this.onExperienceChanged,
  });

  final TextEditingController companyController;
  final TextEditingController roleController;
  final TextEditingController goalsController;
  final double experienceYears;
  final ValueChanged<double> onExperienceChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeading(
            title: 'Your professional background',
            subtitle: 'All optional — GitHub, LeetCode, and similar links are never required.',
          ),
          const SizedBox(height: 24),
          FormSectionCard(
            icon: Icons.work_outline_rounded,
            title: 'Work',
            children: [
              TextField(
                controller: roleController,
                style: const TextStyle(color: HomeStyle.textPrimary),
                decoration: darkInputDecoration('Current role'),
              ),
              TextField(
                controller: companyController,
                style: const TextStyle(color: HomeStyle.textPrimary),
                decoration: darkInputDecoration('Current company'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Total IT experience: ${experienceYears.toStringAsFixed(1)} years',
              style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: HomeStyle.purple,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
              thumbColor: HomeStyle.purple,
              overlayColor: HomeStyle.purple.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: experienceYears,
              min: 0,
              max: 30,
              divisions: 60,
              label: '${experienceYears.toStringAsFixed(1)} yrs',
              onChanged: onExperienceChanged,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: goalsController,
            maxLines: 3,
            style: const TextStyle(color: HomeStyle.textPrimary),
            decoration: darkInputDecoration('Career goals',
                hint: 'e.g. Looking for hackathon teammates and a mentor in ML'),
          ),
        ],
      ),
    );
  }
}

class _SkillsInterestsStep extends ConsumerWidget {
  const _SkillsInterestsStep({
    required this.selectedSkillIds,
    required this.selectedInterestIds,
    required this.onSkillsChanged,
    required this.onInterestsChanged,
  });

  final Set<String> selectedSkillIds;
  final Set<String> selectedInterestIds;
  final VoidCallback onSkillsChanged;
  final VoidCallback onInterestsChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillsAsync = ref.watch(allSkillsProvider);
    final interestsAsync = ref.watch(allInterestsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeading(
            title: 'Skills & interests',
            subtitle: 'Pick a few — this powers your matches across people, teams, and opportunities.',
          ),
          const SizedBox(height: 24),
          const Text('Skills', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          skillsAsync.when(
            data: (skills) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final skill in skills)
                  _DarkChip(
                    label: skill.name,
                    selected: selectedSkillIds.contains(skill.id),
                    onTap: () {
                      selectedSkillIds.contains(skill.id)
                          ? selectedSkillIds.remove(skill.id)
                          : selectedSkillIds.add(skill.id);
                      onSkillsChanged();
                    },
                  ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => const Text('Could not load skills', style: TextStyle(color: HomeStyle.textSecondary)),
          ),
          const SizedBox(height: 22),
          const Text('Interests', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          interestsAsync.when(
            data: (interests) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final interest in interests)
                  _DarkChip(
                    label: interest.name,
                    selected: selectedInterestIds.contains(interest.id),
                    onTap: () {
                      selectedInterestIds.contains(interest.id)
                          ? selectedInterestIds.remove(interest.id)
                          : selectedInterestIds.add(interest.id);
                      onInterestsChanged();
                    },
                  ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => const Text('Could not load interests', style: TextStyle(color: HomeStyle.textSecondary)),
          ),
        ],
      ),
    );
  }
}
