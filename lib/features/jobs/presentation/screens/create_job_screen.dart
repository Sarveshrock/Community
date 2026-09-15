import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/models/skill.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/multi_select_chips.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../profile/presentation/providers/profile_providers.dart' show allSkillsProvider;
import '../providers/job_providers.dart';
import '../widgets/bullet_list_editor.dart';
import '../widgets/job_detail_view.dart';
import '../widgets/job_questions_editor.dart';

const _currencies = ['USD', 'INR', 'EUR', 'GBP'];

/// The Job Builder. A single scrollable, sectioned form (Basics/Role
/// Description/Requirements/Compensation/Benefits/Location/Application
/// Settings/Custom Questions/Deadline), mirroring `CreateEventScreen`'s
/// pattern exactly. Also doubles as the Edit Job screen when [editJobId] is
/// set, prefilling from the existing job.
class CreateJobScreen extends ConsumerStatefulWidget {
  const CreateJobScreen({super.key, this.editJobId});

  final String? editJobId;

  @override
  ConsumerState<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends ConsumerState<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _companyWebsiteController = TextEditingController();
  final _companyDescController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _officeDaysController = TextEditingController();
  final _experienceMinController = TextEditingController();
  final _experienceMaxController = TextEditingController();
  final _educationController = TextEditingController();
  final _prerequisitesController = TextEditingController();
  final _salaryMinController = TextEditingController();
  final _salaryMaxController = TextEditingController();
  final _bonusController = TextEditingController();
  final _equityController = TextEditingController();
  final _internshipDurationController = TextEditingController();
  final _stipendController = TextEditingController();
  final _noticePeriodController = TextEditingController();
  final _engagementDurationController = TextEditingController();
  final _hoursPerWeekController = TextEditingController();
  final _workScheduleController = TextEditingController();
  final _applicationUrlController = TextEditingController();
  final _applicationInstructionsController = TextEditingController();
  final _contactInfoController = TextEditingController();
  final _customBenefitController = TextEditingController();

  bool _initialized = false;
  bool _uploadingLogo = false;
  Uint8List? _logoBytes;
  String? _logoFileExt;
  String? _existingLogoUrl;

  String? _jobCategory;
  JobEmploymentType _employmentType = JobEmploymentType.fullTime;
  WorkMode _workMode = WorkMode.remote;
  List<String> _responsibilities = [];
  final Set<String> _requiredSkillIds = {};
  final Set<String> _preferredSkillIds = {};
  ExperienceLevel? _experienceLevel;
  String _currency = 'USD';
  PayPeriod _payPeriod = PayPeriod.yearly;
  bool _salaryVisible = true;
  bool _salaryNegotiable = false;
  bool _potentialConversion = false;
  DateTime? _contractStartDate;
  DateTime? _contractEndDate;
  bool _renewable = false;
  final Set<String> _benefits = {};
  JobApplicationMethod _applicationMethod = JobApplicationMethod.external;
  bool _resumeRequired = false;
  bool _portfolioRequired = false;
  bool _coverLetterRequired = false;
  List<JobApplicationQuestion> _questions = [];
  DateTime? _deadline;

  bool get _isEditing => widget.editJobId != null;
  bool get _isInternship => _employmentType == JobEmploymentType.internship;
  bool get _isFullTime => _employmentType == JobEmploymentType.fullTime;
  bool get _isFreelance => _employmentType == JobEmploymentType.freelance;
  bool get _isContract => _employmentType == JobEmploymentType.contract;
  bool get _isPartTime => _employmentType == JobEmploymentType.partTime;
  bool get _isResearch => _employmentType == JobEmploymentType.research;
  bool get _isVolunteer => _employmentType == JobEmploymentType.volunteer;
  bool get _isTemporary => _employmentType == JobEmploymentType.temporary;
  bool get _isOther => _employmentType == JobEmploymentType.other;

  // Which fields are shown for the current Employment Type — reused by both
  // the dynamic "___ details" section (what to build) and _buildJobData
  // (what to actually persist, so switching types never leaks the previous
  // type's values into the saved job).
  bool get _showEducation => _isFullTime || _isContract || _isPartTime || _isTemporary || _isOther || _isResearch;
  bool get _showPrerequisites => _isFullTime || _isContract || _isTemporary || _isOther;
  bool get _showSalary => _isFullTime || _isFreelance || _isContract || _isPartTime || _isTemporary || _isOther;
  bool get _showBenefits => _isFullTime || _isVolunteer || _isOther;
  bool get _showStipend => _isInternship || _isResearch;
  bool get _showEngagementDuration =>
      _isFreelance || _isContract || _isPartTime || _isResearch || _isVolunteer || _isTemporary || _isOther;
  bool get _showHoursPerWeek => _isFreelance || _isContract || _isPartTime || _isVolunteer || _isTemporary;
  bool get _showContractDates => _isContract || _isTemporary;

  String get _employmentDetailsTitle => '${_employmentType.label} details';

  String get _responsibilitiesLabel => switch (_employmentType) {
        JobEmploymentType.freelance => 'Deliverables',
        JobEmploymentType.internship => 'Learning outcomes',
        JobEmploymentType.research => 'Research objectives',
        _ => 'Responsibilities',
      };

  String get _responsibilitiesHint => switch (_employmentType) {
        JobEmploymentType.freelance => 'Add a deliverable',
        JobEmploymentType.internship => 'Add a learning outcome',
        JobEmploymentType.research => 'Add a research objective',
        _ => 'Add a responsibility',
      };

  String get _contactInfoLabel => switch (_employmentType) {
        JobEmploymentType.internship => 'Mentor / contact info (optional)',
        JobEmploymentType.research => 'Supervisor / mentor contact (optional)',
        _ => 'Contact info (optional)',
      };

  String get _educationLabel => switch (_employmentType) {
        JobEmploymentType.internship => 'Student eligibility (optional)',
        JobEmploymentType.research => 'Required academic background',
        _ => 'Education (optional)',
      };

  String get _salaryGroupLabel => switch (_employmentType) {
        JobEmploymentType.freelance => 'Budget / rate',
        JobEmploymentType.contract || JobEmploymentType.temporary => 'Compensation',
        JobEmploymentType.partTime => 'Salary / hourly rate',
        _ => 'Salary range',
      };

  String get _stipendLabel => _isResearch ? 'Funding / stipend (optional)' : 'Stipend';

  String get _hoursPerWeekLabel => switch (_employmentType) {
        JobEmploymentType.freelance => 'Expected hours (per week)',
        JobEmploymentType.contract => 'Expected working hours (per week)',
        JobEmploymentType.volunteer => 'Time commitment (hours/week)',
        JobEmploymentType.temporary => 'Working hours (per week)',
        _ => 'Hours per week',
      };

  String get _engagementDurationLabel => switch (_employmentType) {
        JobEmploymentType.contract => 'Contract duration',
        JobEmploymentType.research => 'Research duration',
        _ => 'Duration',
      };

  @override
  void dispose() {
    for (final c in [
      _titleController,
      _companyController,
      _companyWebsiteController,
      _companyDescController,
      _descriptionController,
      _locationController,
      _cityController,
      _stateController,
      _countryController,
      _officeDaysController,
      _experienceMinController,
      _experienceMaxController,
      _educationController,
      _prerequisitesController,
      _salaryMinController,
      _salaryMaxController,
      _bonusController,
      _equityController,
      _internshipDurationController,
      _stipendController,
      _noticePeriodController,
      _engagementDurationController,
      _hoursPerWeekController,
      _workScheduleController,
      _applicationUrlController,
      _applicationInstructionsController,
      _contactInfoController,
      _customBenefitController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(Job job, List<JobApplicationQuestion> questions) {
    if (_initialized) return;
    _titleController.text = job.title;
    _companyController.text = job.companyName;
    _companyWebsiteController.text = job.companyWebsite ?? '';
    _companyDescController.text = job.companyDescription ?? '';
    _descriptionController.text = job.description ?? '';
    _locationController.text = job.location ?? '';
    _cityController.text = job.city ?? '';
    _stateController.text = job.state ?? '';
    _countryController.text = job.country ?? '';
    _officeDaysController.text = job.expectedOfficeDays ?? '';
    _experienceMinController.text = job.experienceMinMonths?.toString() ?? '';
    _experienceMaxController.text = job.experienceMaxMonths?.toString() ?? '';
    _educationController.text = job.education ?? '';
    _prerequisitesController.text = job.prerequisites ?? '';
    _salaryMinController.text = job.salaryMin?.toStringAsFixed(0) ?? '';
    _salaryMaxController.text = job.salaryMax?.toStringAsFixed(0) ?? '';
    _bonusController.text = job.bonusInfo ?? '';
    _equityController.text = job.equityInfo ?? '';
    _internshipDurationController.text = job.internshipDurationMonths?.toString() ?? '';
    _stipendController.text = job.stipend?.toStringAsFixed(0) ?? '';
    _noticePeriodController.text = job.noticePeriodDays?.toString() ?? '';
    _engagementDurationController.text = job.engagementDuration ?? '';
    _hoursPerWeekController.text = job.hoursPerWeek?.toString() ?? '';
    _workScheduleController.text = job.workSchedule ?? '';
    _contractStartDate = job.contractStartDate;
    _contractEndDate = job.contractEndDate;
    _renewable = job.renewable;
    _applicationUrlController.text = job.applicationUrl ?? '';
    _applicationInstructionsController.text = job.applicationInstructions ?? '';
    _contactInfoController.text = job.contactInfo ?? '';
    _existingLogoUrl = job.companyLogoUrl;
    _jobCategory = job.jobCategory;
    _employmentType = job.employmentType;
    _workMode = job.workMode;
    _experienceLevel = job.experienceLevel;
    _currency = job.currency ?? 'USD';
    _payPeriod = job.payPeriod ?? PayPeriod.yearly;
    _salaryVisible = job.salaryVisible;
    _salaryNegotiable = job.salaryNegotiable;
    _potentialConversion = job.potentialConversion;
    _benefits
      ..clear()
      ..addAll(job.benefits);
    _applicationMethod = job.applicationMethod;
    _resumeRequired = job.resumeRequired;
    _portfolioRequired = job.portfolioRequired;
    _coverLetterRequired = job.coverLetterRequired;
    _deadline = job.deadline?.toLocal();
    _questions = questions;
    _initialized = true;
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 90);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _logoBytes = bytes;
      _logoFileExt = file.name.split('.').last;
    });
  }

  Future<void> _pickDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null) return;
    setState(() => _deadline = date);
  }

  Future<void> _pickContractDate({required bool isStart}) async {
    final initial = (isStart ? _contractStartDate : _contractEndDate) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
    );
    if (date == null) return;
    setState(() => isStart ? _contractStartDate = date : _contractEndDate = date);
  }

  void _addCustomBenefit() {
    final text = _customBenefitController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _benefits.add(text);
      _customBenefitController.clear();
    });
  }

  Map<String, dynamic> _buildJobData() {
    return {
      'title': _titleController.text.trim(),
      'company_name': _companyController.text.trim(),
      'company_website': _companyWebsiteController.text.trim().isEmpty ? null : _companyWebsiteController.text.trim(),
      'company_description':
          _companyDescController.text.trim().isEmpty ? null : _companyDescController.text.trim(),
      'job_category': _jobCategory,
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      'employment_type': _employmentType.value,
      'work_mode': _workMode.value,
      'location': _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      if (_workMode != WorkMode.remote) 'city': _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      if (_workMode != WorkMode.remote)
        'state': _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
      if (_workMode != WorkMode.remote)
        'country': _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
      if (_workMode == WorkMode.hybrid)
        'expected_office_days': _officeDaysController.text.trim().isEmpty ? null : _officeDaysController.text.trim(),
      // Every employment-type-specific field below is always sent, valued
      // null when the current type doesn't show it — so switching types
      // and submitting never leaks a previous type's leftover values into
      // the saved job (e.g. Internship's duration/stipend must not survive
      // as Full-time data). The on-screen TextEditingControllers keep their
      // text regardless, so switching back during the same session still
      // shows what was typed.
      'experience_level': _isFullTime ? _experienceLevel?.name : null,
      'experience_min_months': _isFullTime ? int.tryParse(_experienceMinController.text.trim()) : null,
      'experience_max_months': _isFullTime ? int.tryParse(_experienceMaxController.text.trim()) : null,
      'education': _showEducation && _educationController.text.trim().isNotEmpty
          ? _educationController.text.trim()
          : null,
      'prerequisites': _showPrerequisites && _prerequisitesController.text.trim().isNotEmpty
          ? _prerequisitesController.text.trim()
          : null,
      'salary_min': _showSalary ? num.tryParse(_salaryMinController.text.trim()) : null,
      'salary_max': _showSalary ? num.tryParse(_salaryMaxController.text.trim()) : null,
      'currency': _currency,
      'pay_period': _showSalary ? _payPeriod.value : null,
      'salary_visible': _showSalary && _salaryVisible,
      'salary_negotiable': _showSalary && _salaryNegotiable,
      'bonus_info':
          _isFullTime && _bonusController.text.trim().isNotEmpty ? _bonusController.text.trim() : null,
      'equity_info':
          _isFullTime && _equityController.text.trim().isNotEmpty ? _equityController.text.trim() : null,
      'benefits': _showBenefits ? _benefits.toList() : const <String>[],
      'internship_duration_months':
          _isInternship ? int.tryParse(_internshipDurationController.text.trim()) : null,
      'stipend': _showStipend ? num.tryParse(_stipendController.text.trim()) : null,
      'potential_conversion': _isInternship && _potentialConversion,
      'notice_period_days': _isFullTime ? int.tryParse(_noticePeriodController.text.trim()) : null,
      'engagement_duration': _showEngagementDuration && _engagementDurationController.text.trim().isNotEmpty
          ? _engagementDurationController.text.trim()
          : null,
      'hours_per_week': _showHoursPerWeek ? int.tryParse(_hoursPerWeekController.text.trim()) : null,
      'work_schedule':
          _isPartTime && _workScheduleController.text.trim().isNotEmpty ? _workScheduleController.text.trim() : null,
      'contract_start_date':
          _showContractDates ? _contractStartDate?.toIso8601String().substring(0, 10) : null,
      'contract_end_date': _showContractDates ? _contractEndDate?.toIso8601String().substring(0, 10) : null,
      'renewable': _isContract && _renewable,
      'application_method': _applicationMethod.value,
      'application_url': _applicationMethod == JobApplicationMethod.external
          ? (_applicationUrlController.text.trim().isEmpty ? null : _applicationUrlController.text.trim())
          : null,
      'application_instructions':
          _applicationInstructionsController.text.trim().isEmpty ? null : _applicationInstructionsController.text.trim(),
      if (_applicationMethod == JobApplicationMethod.communeo) 'resume_required': _resumeRequired,
      if (_applicationMethod == JobApplicationMethod.communeo) 'portfolio_required': _portfolioRequired,
      if (_applicationMethod == JobApplicationMethod.communeo) 'cover_letter_required': _coverLetterRequired,
      'contact_info': _contactInfoController.text.trim().isEmpty ? null : _contactInfoController.text.trim(),
      'deadline': _deadline?.toIso8601String(),
    };
  }

  Job _previewJob({required List<String> requiredNames, required List<String> preferredNames}) {
    return Job(
      id: widget.editJobId ?? 'preview',
      posterId: '',
      companyName: _companyController.text.trim().isEmpty ? 'Your company' : _companyController.text.trim(),
      companyLogoUrl: _existingLogoUrl,
      companyWebsite: _companyWebsiteController.text.trim().isEmpty ? null : _companyWebsiteController.text.trim(),
      companyDescription: _companyDescController.text.trim().isEmpty ? null : _companyDescController.text.trim(),
      title: _titleController.text.trim().isEmpty ? 'Untitled role' : _titleController.text.trim(),
      jobCategory: _jobCategory,
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      employmentType: _employmentType,
      workMode: _workMode,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      state: _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
      country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
      expectedOfficeDays: _officeDaysController.text.trim().isEmpty ? null : _officeDaysController.text.trim(),
      responsibilities: _responsibilities,
      experienceLevel: _isFullTime ? _experienceLevel : null,
      experienceMinMonths: _isFullTime ? int.tryParse(_experienceMinController.text.trim()) : null,
      experienceMaxMonths: _isFullTime ? int.tryParse(_experienceMaxController.text.trim()) : null,
      education: _showEducation && _educationController.text.trim().isNotEmpty ? _educationController.text.trim() : null,
      prerequisites:
          _showPrerequisites && _prerequisitesController.text.trim().isNotEmpty ? _prerequisitesController.text.trim() : null,
      salaryMin: _showSalary ? num.tryParse(_salaryMinController.text.trim()) : null,
      salaryMax: _showSalary ? num.tryParse(_salaryMaxController.text.trim()) : null,
      currency: _currency,
      payPeriod: _showSalary ? _payPeriod : null,
      salaryVisible: _showSalary && _salaryVisible,
      salaryNegotiable: _showSalary && _salaryNegotiable,
      bonusInfo: _isFullTime && _bonusController.text.trim().isNotEmpty ? _bonusController.text.trim() : null,
      equityInfo: _isFullTime && _equityController.text.trim().isNotEmpty ? _equityController.text.trim() : null,
      benefits: _showBenefits ? _benefits.toList() : const [],
      internshipDurationMonths: _isInternship ? int.tryParse(_internshipDurationController.text.trim()) : null,
      stipend: _showStipend ? num.tryParse(_stipendController.text.trim()) : null,
      potentialConversion: _isInternship && _potentialConversion,
      noticePeriodDays: _isFullTime ? int.tryParse(_noticePeriodController.text.trim()) : null,
      engagementDuration: _showEngagementDuration && _engagementDurationController.text.trim().isNotEmpty
          ? _engagementDurationController.text.trim()
          : null,
      hoursPerWeek: _showHoursPerWeek ? int.tryParse(_hoursPerWeekController.text.trim()) : null,
      workSchedule:
          _isPartTime && _workScheduleController.text.trim().isNotEmpty ? _workScheduleController.text.trim() : null,
      contractStartDate: _showContractDates ? _contractStartDate : null,
      contractEndDate: _showContractDates ? _contractEndDate : null,
      renewable: _isContract && _renewable,
      applicationMethod: _applicationMethod,
      applicationUrl: _applicationUrlController.text.trim().isEmpty ? null : _applicationUrlController.text.trim(),
      applicationInstructions:
          _applicationInstructionsController.text.trim().isEmpty ? null : _applicationInstructionsController.text.trim(),
      resumeRequired: _resumeRequired,
      portfolioRequired: _portfolioRequired,
      coverLetterRequired: _coverLetterRequired,
      contactInfo: _contactInfoController.text.trim().isEmpty ? null : _contactInfoController.text.trim(),
      deadline: _deadline,
      createdAt: DateTime.now(),
      requiredSkillNames: requiredNames,
      preferredSkillNames: preferredNames,
    );
  }

  void _openPreview(List<Skill> skills) {
    if (_titleController.text.trim().isEmpty || _companyController.text.trim().isEmpty) {
      context.showSnack('Add a title and company before previewing', isError: true);
      return;
    }
    final preview = _previewJob(
      requiredNames: [for (final s in skills) if (_requiredSkillIds.contains(s.id)) s.name],
      preferredNames: [for (final s in skills) if (_preferredSkillIds.contains(s.id)) s.name],
    );
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: HomeStyle.background,
        body: SafeArea(
          child: Stack(
            children: [
              JobDetailView(
                job: preview,
                logoBytesPreview: _logoBytes != null ? MemoryImage(_logoBytes!) : null,
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
    final controller = ref.read(jobControllerProvider.notifier);
    final data = {..._buildJobData(), 'responsibilities': _responsibilities};

    if (_isEditing) {
      final ok = await controller.updateJob(
        widget.editJobId!,
        data,
        requiredSkillIds: _requiredSkillIds.toList(),
        preferredSkillIds: _preferredSkillIds.toList(),
        questions: _applicationMethod == JobApplicationMethod.communeo ? _questions : [],
      );
      if (!mounted) return;
      if (ok) {
        context.showSnack('Job updated');
        context.pop();
      } else {
        context.showSnack('Could not update job', isError: true);
      }
      return;
    }

    final created = await controller.createJob(
      data,
      requiredSkillIds: _requiredSkillIds.toList(),
      preferredSkillIds: _preferredSkillIds.toList(),
      questions: _applicationMethod == JobApplicationMethod.communeo ? _questions : [],
    );
    if (!mounted) return;
    if (created == null) {
      context.showSnack('Could not post job', isError: true);
      return;
    }
    if (_logoBytes != null && _logoFileExt != null) {
      setState(() => _uploadingLogo = true);
      final url = await controller.uploadCompanyLogo(created.id, _logoBytes!, _logoFileExt!);
      if (url != null) {
        await controller.updateJob(created.id, {'company_logo_url': url});
      }
      if (mounted) setState(() => _uploadingLogo = false);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      final jobAsync = ref.watch(jobDetailProvider(widget.editJobId!));
      final questionsAsync = ref.watch(jobApplicationQuestionsProvider(widget.editJobId!));
      if (jobAsync.isLoading || questionsAsync.isLoading) {
        return const Scaffold(backgroundColor: HomeStyle.background, body: LoadingState());
      }
      if (jobAsync.hasError) {
        return Scaffold(backgroundColor: HomeStyle.background, body: ErrorState(message: jobAsync.error.toString()));
      }
      _hydrate(jobAsync.value!, questionsAsync.valueOrNull ?? []);
      _responsibilities = jobAsync.value!.responsibilities;
    }
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) {
    final isSaving = ref.watch(jobControllerProvider).isLoading || _uploadingLogo;
    final skillsAsync = ref.watch(allSkillsProvider);

    return Scaffold(
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: HomeStyle.background,
        title: Text(_isEditing ? 'Edit Job' : 'Post a Job', style: const TextStyle(color: HomeStyle.textPrimary)),
        iconTheme: const IconThemeData(color: HomeStyle.textPrimary),
        actions: [
          TextButton(
            onPressed: () => _openPreview(skillsAsync.valueOrNull ?? []),
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
                  title: 'Job basics',
                  children: [
                    _LogoPicker(bytes: _logoBytes, existingUrl: _existingLogoUrl, onTap: _pickLogo),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Job title'),
                      validator: (v) => Validators.required(v, fieldName: 'Title'),
                    ),
                    TextFormField(
                      controller: _companyController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Company name'),
                      validator: (v) => Validators.required(v, fieldName: 'Company'),
                    ),
                    TextFormField(
                      controller: _companyWebsiteController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Company website (optional)'),
                      validator: Validators.url,
                    ),
                    TextFormField(
                      controller: _companyDescController,
                      maxLines: 2,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('About the company (optional)'),
                    ),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _jobCategory,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Category'),
                      items: [for (final c in kJobCategories) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => setState(() => _jobCategory = v),
                    ),
                    DropdownButtonFormField<JobEmploymentType>(
                      isExpanded: true,
                      initialValue: _employmentType,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Employment type'),
                      items: [
                        for (final t in JobEmploymentType.values) DropdownMenuItem(value: t, child: Text(t.label)),
                      ],
                      onChanged: (v) => setState(() => _employmentType = v ?? _employmentType),
                    ),
                    DropdownButtonFormField<WorkMode>(
                      isExpanded: true,
                      initialValue: _workMode,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Work mode'),
                      items: [for (final m in WorkMode.values) DropdownMenuItem(value: m, child: Text(m.label))],
                      onChanged: (v) => setState(() => _workMode = v ?? _workMode),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.description_outlined,
                  title: 'Role description',
                  children: [
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('About this role'),
                    ),
                    Text(_responsibilitiesLabel, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    BulletListEditor(
                      items: _responsibilities,
                      hint: _responsibilitiesHint,
                      onChanged: (v) => setState(() => _responsibilities = v),
                    ),
                  ],
                ),
                // The fields shown here change with Employment Type — e.g.
                // Internship shows duration/stipend/conversion, Contract
                // shows start/end dates and renewal, Volunteer shows time
                // commitment and recognition. See _employmentDetailFields.
                FormSectionCard(
                  key: ValueKey(_employmentType),
                  icon: Icons.tune_rounded,
                  title: _employmentDetailsTitle,
                  children: _employmentDetailFields,
                ),
                FormSectionCard(
                  icon: Icons.checklist_rounded,
                  title: 'Skills',
                  children: [
                    const Text('Required skills', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    skillsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Could not load skills'),
                      data: (skills) => MultiSelectChips(
                        options: [for (final s in skills) s.name],
                        selected: {for (final s in skills) if (_requiredSkillIds.contains(s.id)) s.name},
                        onChanged: (selectedNames) {
                          setState(() {
                            _requiredSkillIds
                              ..clear()
                              ..addAll([for (final s in skills) if (selectedNames.contains(s.name)) s.id]);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Nice-to-have skills', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    skillsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Could not load skills'),
                      data: (skills) => MultiSelectChips(
                        options: [for (final s in skills) s.name],
                        selected: {for (final s in skills) if (_preferredSkillIds.contains(s.id)) s.name},
                        onChanged: (selectedNames) {
                          setState(() {
                            _preferredSkillIds
                              ..clear()
                              ..addAll([for (final s in skills) if (selectedNames.contains(s.name)) s.id]);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                FormSectionCard(
                  icon: Icons.place_outlined,
                  title: 'Location',
                  children: [
                    if (_workMode == WorkMode.remote)
                      const Text('Remote roles don\'t need a physical location.',
                          style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5))
                    else ...[
                      TextFormField(
                        controller: _locationController,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Location (display text)', hint: 'e.g. Bengaluru, India'),
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
                        controller: _countryController,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Country'),
                      ),
                      if (_workMode == WorkMode.hybrid)
                        TextFormField(
                          controller: _officeDaysController,
                          style: const TextStyle(color: HomeStyle.textPrimary),
                          decoration: darkInputDecoration('Expected office days', hint: 'e.g. 3 days/week'),
                        ),
                    ],
                  ],
                ),
                FormSectionCard(
                  icon: Icons.send_outlined,
                  title: 'Application settings',
                  children: [
                    DropdownButtonFormField<JobApplicationMethod>(
                      isExpanded: true,
                      initialValue: _applicationMethod,
                      dropdownColor: HomeStyle.cardBase,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('How should candidates apply?'),
                      items: const [
                        DropdownMenuItem(value: JobApplicationMethod.communeo, child: Text('Apply on Communeo')),
                        DropdownMenuItem(value: JobApplicationMethod.external, child: Text('Apply on an external site')),
                      ],
                      onChanged: (v) => setState(() => _applicationMethod = v ?? _applicationMethod),
                    ),
                    if (_applicationMethod == JobApplicationMethod.external)
                      TextFormField(
                        controller: _applicationUrlController,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('External application URL'),
                        validator: (v) => _applicationMethod == JobApplicationMethod.external
                            ? Validators.required(v, fieldName: 'Application URL') ?? Validators.url(v)
                            : null,
                      )
                    else ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Require resume', style: TextStyle(color: HomeStyle.textPrimary)),
                        value: _resumeRequired,
                        onChanged: (v) => setState(() => _resumeRequired = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Require portfolio', style: TextStyle(color: HomeStyle.textPrimary)),
                        value: _portfolioRequired,
                        onChanged: (v) => setState(() => _portfolioRequired = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Require cover letter', style: TextStyle(color: HomeStyle.textPrimary)),
                        value: _coverLetterRequired,
                        onChanged: (v) => setState(() => _coverLetterRequired = v),
                      ),
                    ],
                    TextFormField(
                      controller: _applicationInstructionsController,
                      maxLines: 2,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Application instructions (optional)'),
                    ),
                    TextFormField(
                      controller: _contactInfoController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration(_contactInfoLabel),
                    ),
                    OutlinedButton(
                      onPressed: _pickDeadline,
                      child: Text(_deadline == null
                          ? 'Application deadline (optional)'
                          : 'Deadline: ${_deadline!.month}/${_deadline!.day}/${_deadline!.year}'),
                    ),
                  ],
                ),
                if (_applicationMethod == JobApplicationMethod.communeo)
                  FormSectionCard(
                    icon: Icons.quiz_outlined,
                    title: 'Custom application questions',
                    subtitle: 'Optional — shown to every applicant',
                    children: [JobQuestionsEditor(questions: _questions, onChanged: (v) => setState(() => _questions = v))],
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
                            : Text(_isEditing ? 'Save changes' : 'Post job',
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

  // Employment-Type-specific fields for the dynamic "___ details" section.
  // Every field here reuses an existing Job column (relabeled per type)
  // except the small set added in 0044_job_employment_type_fields.sql
  // (engagement duration, hours/week, work schedule, contract dates,
  // renewable) — see _buildJobData/_previewJob for how irrelevant fields
  // are nulled out rather than left over when the user switches types.
  List<Widget> get _employmentDetailFields {
    switch (_employmentType) {
      case JobEmploymentType.fullTime:
        return [
          _experienceFields(),
          _educationField(),
          _prerequisitesField(),
          _salaryGroup(),
          _bonusEquityGroup(),
          _noticePeriodField(),
          _benefitsGroup(),
        ];
      case JobEmploymentType.internship:
        return [
          _internshipGroup(),
          _educationField(),
        ];
      case JobEmploymentType.freelance:
        return [
          _engagementDurationField(),
          _salaryGroup(),
          _hoursPerWeekField(),
        ];
      case JobEmploymentType.contract:
        return [
          _engagementDurationField(),
          _contractDatesRow(),
          _renewableSwitch(),
          _salaryGroup(),
          _hoursPerWeekField(),
          _educationField(),
          _prerequisitesField(),
        ];
      case JobEmploymentType.partTime:
        return [
          _hoursPerWeekField(),
          _workScheduleField(),
          _engagementDurationField(),
          _salaryGroup(),
          _educationField(),
        ];
      case JobEmploymentType.research:
        return [
          _educationField(),
          _engagementDurationField(),
          _stipendField(),
        ];
      case JobEmploymentType.volunteer:
        return [
          _hoursPerWeekField(),
          _engagementDurationField(),
          _benefitsGroup(title: 'Certificate / recognition (optional)'),
        ];
      case JobEmploymentType.temporary:
        return [
          _contractDatesRow(),
          _engagementDurationField(),
          _salaryGroup(),
          _hoursPerWeekField(),
          _prerequisitesField(),
        ];
      case JobEmploymentType.other:
        return [
          _engagementDurationField(),
          _salaryGroup(),
          _benefitsGroup(),
          _educationField(),
          _prerequisitesField(),
        ];
    }
  }

  Widget _experienceFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _experienceMinController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: HomeStyle.textPrimary),
                decoration: darkInputDecoration('Min experience (months)'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _experienceMaxController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: HomeStyle.textPrimary),
                decoration: darkInputDecoration('Max experience (months)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ExperienceLevel?>(
          isExpanded: true,
          initialValue: _experienceLevel,
          dropdownColor: HomeStyle.cardBase,
          style: const TextStyle(color: HomeStyle.textPrimary),
          decoration: darkInputDecoration('Experience level (optional)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Not specified')),
            for (final l in ExperienceLevel.values) DropdownMenuItem(value: l, child: Text(l.jobLabel)),
          ],
          onChanged: (v) => setState(() => _experienceLevel = v),
        ),
      ],
    );
  }

  Widget _educationField() {
    return TextFormField(
      controller: _educationController,
      style: const TextStyle(color: HomeStyle.textPrimary),
      decoration: darkInputDecoration(_educationLabel, hint: "e.g. Bachelor's in CS"),
    );
  }

  Widget _prerequisitesField() {
    return TextFormField(
      controller: _prerequisitesController,
      maxLines: 2,
      style: const TextStyle(color: HomeStyle.textPrimary),
      decoration: darkInputDecoration('Prerequisites (optional)'),
    );
  }

  Widget _salaryGroup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_salaryGroupLabel, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _salaryMinController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: HomeStyle.textPrimary),
                decoration: darkInputDecoration('Min'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _salaryMaxController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: HomeStyle.textPrimary),
                decoration: darkInputDecoration('Max'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
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
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<PayPeriod>(
                isExpanded: true,
                initialValue: _payPeriod,
                dropdownColor: HomeStyle.cardBase,
                style: const TextStyle(color: HomeStyle.textPrimary),
                decoration: darkInputDecoration('Pay period'),
                items: [for (final p in PayPeriod.values) DropdownMenuItem(value: p, child: Text(p.name))],
                onChanged: (v) => setState(() => _payPeriod = v ?? _payPeriod),
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show this on the job post', style: TextStyle(color: HomeStyle.textPrimary)),
          value: _salaryVisible,
          onChanged: (v) => setState(() => _salaryVisible = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Negotiable', style: TextStyle(color: HomeStyle.textPrimary)),
          value: _salaryNegotiable,
          onChanged: (v) => setState(() => _salaryNegotiable = v),
        ),
      ],
    );
  }

  Widget _bonusEquityGroup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _bonusController,
          style: const TextStyle(color: HomeStyle.textPrimary),
          decoration: darkInputDecoration('Bonus (optional)'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _equityController,
          style: const TextStyle(color: HomeStyle.textPrimary),
          decoration: darkInputDecoration('Equity / ESOP (optional)'),
        ),
      ],
    );
  }

  Widget _noticePeriodField() {
    return TextFormField(
      controller: _noticePeriodController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: HomeStyle.textPrimary),
      decoration: darkInputDecoration('Notice period (days, optional)'),
    );
  }

  Widget _internshipGroup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _internshipDurationController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: HomeStyle.textPrimary),
                decoration: darkInputDecoration('Duration (months)'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _stipendController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: HomeStyle.textPrimary),
                decoration: darkInputDecoration('Stipend', hint: 'Leave blank if unpaid'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Potential full-time conversion', style: TextStyle(color: HomeStyle.textPrimary)),
          value: _potentialConversion,
          onChanged: (v) => setState(() => _potentialConversion = v),
        ),
      ],
    );
  }

  Widget _stipendField() {
    return TextFormField(
      controller: _stipendController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: HomeStyle.textPrimary),
      decoration: darkInputDecoration(_stipendLabel),
    );
  }

  Widget _engagementDurationField() {
    return TextFormField(
      controller: _engagementDurationController,
      style: const TextStyle(color: HomeStyle.textPrimary),
      decoration: darkInputDecoration(_engagementDurationLabel, hint: 'e.g. 3 months, 6 weeks, ongoing'),
    );
  }

  Widget _hoursPerWeekField() {
    return TextFormField(
      controller: _hoursPerWeekController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: HomeStyle.textPrimary),
      decoration: darkInputDecoration(_hoursPerWeekLabel),
    );
  }

  Widget _workScheduleField() {
    return TextFormField(
      controller: _workScheduleController,
      style: const TextStyle(color: HomeStyle.textPrimary),
      decoration: darkInputDecoration('Working schedule (optional)', hint: 'e.g. Mon-Fri mornings'),
    );
  }

  Widget _contractDatesRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _pickContractDate(isStart: true),
            child: Text(_contractStartDate == null
                ? 'Start date (optional)'
                : 'Start: ${_contractStartDate!.month}/${_contractStartDate!.day}/${_contractStartDate!.year}'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _pickContractDate(isStart: false),
            child: Text(_contractEndDate == null
                ? 'End date (optional)'
                : 'End: ${_contractEndDate!.month}/${_contractEndDate!.day}/${_contractEndDate!.year}'),
          ),
        ),
      ],
    );
  }

  Widget _renewableSwitch() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Renewal possible', style: TextStyle(color: HomeStyle.textPrimary)),
      value: _renewable,
      onChanged: (v) => setState(() => _renewable = v),
    );
  }

  Widget _benefitsGroup({String title = 'Benefits'}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
        const SizedBox(height: 6),
        MultiSelectChips(
          options: {...kJobBenefits, ..._benefits}.toList(),
          selected: _benefits,
          onChanged: (v) => setState(() {
            _benefits
              ..clear()
              ..addAll(v);
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customBenefitController,
                style: const TextStyle(color: HomeStyle.textPrimary),
                decoration: darkInputDecoration('Add a custom one'),
                onSubmitted: (_) => _addCustomBenefit(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(onPressed: _addCustomBenefit, icon: const Icon(Icons.add_rounded)),
          ],
        ),
      ],
    );
  }
}

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({required this.bytes, required this.existingUrl, required this.onTap});

  final Uint8List? bytes;
  final String? existingUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 96,
        width: 96,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
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
                child: Icon(Icons.add_photo_alternate_outlined, color: HomeStyle.textSecondary, size: 26),
              )
            : null,
      ),
    );
  }
}
