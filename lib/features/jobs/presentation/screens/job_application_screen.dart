import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/job_providers.dart';

/// The internal application flow for a Communeo-hosted job. Pre-fills from
/// the applicant's existing profile (name/skills/experience/education —
/// read-only, not re-entry), collects resume/portfolio via real file upload
/// to the private `resumes` bucket, GitHub/LinkedIn links, the job's custom
/// questions, then a review step before submitting.
class JobApplicationScreen extends ConsumerStatefulWidget {
  const JobApplicationScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobApplicationScreen> createState() => _JobApplicationScreenState();
}

class _JobApplicationScreenState extends ConsumerState<JobApplicationScreen> {
  final _coverLetterController = TextEditingController();
  final _githubController = TextEditingController();
  final _linkedinController = TextEditingController();
  final Map<String, TextEditingController> _questionControllers = {};
  final Map<String, bool> _yesNoAnswers = {};

  bool _initialized = false;
  bool _reviewing = false;
  bool _submitting = false;
  bool _submitted = false;

  Uint8List? _resumeBytes;
  String? _resumeName;
  String? _resumeExt;
  Uint8List? _portfolioBytes;
  String? _portfolioName;
  String? _portfolioExt;

  @override
  void dispose() {
    _coverLetterController.dispose();
    _githubController.dispose();
    _linkedinController.dispose();
    for (final c in _questionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(List<JobApplicationQuestion> questions) {
    if (_initialized) return;
    for (final q in questions) {
      if (q.questionType == JobQuestionType.yesNo) {
        _yesNoAnswers[q.id] = false;
      } else {
        _questionControllers[q.id] = TextEditingController();
      }
    }
    _initialized = true;
  }

  Future<void> _pickFile({required bool isResume}) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    setState(() {
      if (isResume) {
        _resumeBytes = bytes;
        _resumeName = file.name;
        _resumeExt = (file.extension ?? 'pdf').toLowerCase();
      } else {
        _portfolioBytes = bytes;
        _portfolioName = file.name;
        _portfolioExt = (file.extension ?? 'pdf').toLowerCase();
      }
    });
  }

  bool _validate(Job job, List<JobApplicationQuestion> questions) {
    if (job.resumeRequired && _resumeBytes == null) {
      context.showSnack('A resume is required for this role', isError: true);
      return false;
    }
    if (job.portfolioRequired && _portfolioBytes == null) {
      context.showSnack('A portfolio is required for this role', isError: true);
      return false;
    }
    if (job.coverLetterRequired && _coverLetterController.text.trim().isEmpty) {
      context.showSnack('A cover letter is required for this role', isError: true);
      return false;
    }
    for (final q in questions) {
      if (!q.isRequired) continue;
      if (q.questionType == JobQuestionType.yesNo) continue;
      if ((_questionControllers[q.id]?.text.trim() ?? '').isEmpty) {
        context.showSnack('Please answer: ${q.questionText}', isError: true);
        return false;
      }
    }
    return true;
  }

  Future<void> _submit(String myId, List<JobApplicationQuestion> questions) async {
    setState(() => _submitting = true);
    final controller = ref.read(jobControllerProvider.notifier);

    String? resumePath;
    if (_resumeBytes != null && _resumeExt != null) {
      resumePath = await controller.uploadApplicationFile(myId, widget.jobId, _resumeBytes!, _resumeExt!, kind: 'resume');
    }
    String? portfolioPath;
    if (_portfolioBytes != null && _portfolioExt != null) {
      portfolioPath =
          await controller.uploadApplicationFile(myId, widget.jobId, _portfolioBytes!, _portfolioExt!, kind: 'portfolio');
    }

    final answers = <String, String>{
      for (final q in questions)
        if (q.questionType == JobQuestionType.yesNo)
          q.id: (_yesNoAnswers[q.id] ?? false) ? 'Yes' : 'No'
        else if ((_questionControllers[q.id]?.text.trim() ?? '').isNotEmpty)
          q.id: _questionControllers[q.id]!.text.trim(),
    };

    final ok = await controller.apply(
      widget.jobId,
      coverMessage: _coverLetterController.text.trim().isEmpty ? null : _coverLetterController.text.trim(),
      resumePath: resumePath,
      portfolioPath: portfolioPath,
      githubUrl: _githubController.text.trim().isEmpty ? null : _githubController.text.trim(),
      linkedinUrl: _linkedinController.text.trim().isEmpty ? null : _linkedinController.text.trim(),
      questionAnswers: answers,
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      setState(() => _submitted = true);
    } else {
      context.showSnack('Could not submit your application', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(jobDetailProvider(widget.jobId));
    final questionsAsync = ref.watch(jobApplicationQuestionsProvider(widget.jobId));
    final profileAsync = ref.watch(myProfileProvider);
    final experiencesAsync = ref.watch(myExperiencesProvider);
    final educationAsync = ref.watch(myEducationProvider);
    final proofsAsync = ref.watch(myOptionalProofsProvider);
    final myId = ref.watch(authStateProvider).valueOrNull?.id;

    if (jobAsync.isLoading || questionsAsync.isLoading || profileAsync.isLoading) {
      return const Scaffold(backgroundColor: HomeStyle.background, body: LoadingState());
    }
    if (jobAsync.hasError || myId == null) {
      return Scaffold(
        backgroundColor: HomeStyle.background,
        body: ErrorState(message: jobAsync.error?.toString() ?? 'Sign in to apply'),
      );
    }

    final job = jobAsync.value!;
    final questions = questionsAsync.valueOrNull ?? [];
    _hydrate(questions);

    if (!job.isInternalApplication) {
      return const Scaffold(
        backgroundColor: HomeStyle.background,
        body: ErrorState(message: 'This job accepts external applications only.'),
      );
    }

    if (_submitted) {
      return _SuccessView(onDone: () => context.go('/jobs/${widget.jobId}'));
    }

    final profile = profileAsync.valueOrNull;
    final githubProof = proofsAsync.valueOrNull?.where((p) => p.proofType == ProofType.github).firstOrNull;
    final portfolioProof = proofsAsync.valueOrNull?.where((p) => p.proofType == ProofType.portfolio).firstOrNull;
    if (_githubController.text.isEmpty && githubProof?.url != null) {
      _githubController.text = githubProof!.url!;
    }

    return Scaffold(
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: HomeStyle.background,
        title: Text(_reviewing ? 'Review application' : 'Apply — ${job.title}',
            style: const TextStyle(color: HomeStyle.textPrimary)),
        iconTheme: const IconThemeData(color: HomeStyle.textPrimary),
      ),
      body: ResponsiveCenter(
        maxWidth: 560,
        child: _reviewing
            ? _ReviewStep(
                job: job,
                questions: questions,
                profile: profile,
                coverLetter: _coverLetterController.text.trim(),
                resumeName: _resumeName,
                portfolioName: _portfolioName,
                githubUrl: _githubController.text.trim(),
                linkedinUrl: _linkedinController.text.trim(),
                answers: {
                  for (final q in questions)
                    q.questionText: q.questionType == JobQuestionType.yesNo
                        ? ((_yesNoAnswers[q.id] ?? false) ? 'Yes' : 'No')
                        : (_questionControllers[q.id]?.text.trim() ?? ''),
                },
                submitting: _submitting,
                onBack: () => setState(() => _reviewing = false),
                onSubmit: () => _submit(myId, questions),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FormSectionCard(
                      icon: Icons.person_outline_rounded,
                      title: 'Your details',
                      subtitle: 'From your Communeo profile',
                      children: [
                        _ReadOnlyRow(label: 'Name', value: profile?.displayName ?? '—'),
                        if (profile?.currentRole != null) _ReadOnlyRow(label: 'Current role', value: profile!.headline),
                        if (profile?.skills.isNotEmpty ?? false)
                          _ReadOnlyRow(label: 'Skills', value: profile!.skills.map((s) => s.skill.name).join(', ')),
                        if (educationAsync.valueOrNull?.isNotEmpty ?? false)
                          _ReadOnlyRow(
                              label: 'Education',
                              value: educationAsync.value!.first.institution),
                        if (experiencesAsync.valueOrNull?.isNotEmpty ?? false)
                          _ReadOnlyRow(
                              label: 'Experience',
                              value: '${experiencesAsync.value!.first.role} at ${experiencesAsync.value!.first.companyName}'),
                      ],
                    ),
                    FormSectionCard(
                      icon: Icons.attach_file_rounded,
                      title: 'Resume & portfolio',
                      children: [
                        _FilePickerTile(
                          label: job.resumeRequired ? 'Resume (required)' : 'Resume (optional)',
                          fileName: _resumeName,
                          onTap: () => _pickFile(isResume: true),
                        ),
                        _FilePickerTile(
                          label: job.portfolioRequired ? 'Portfolio (required)' : 'Portfolio (optional)',
                          fileName: _portfolioName,
                          onTap: () => _pickFile(isResume: false),
                        ),
                        TextField(
                          controller: _githubController,
                          style: const TextStyle(color: HomeStyle.textPrimary),
                          decoration: darkInputDecoration('GitHub URL (optional)'),
                        ),
                        TextField(
                          controller: _linkedinController,
                          style: const TextStyle(color: HomeStyle.textPrimary),
                          decoration: darkInputDecoration('LinkedIn URL (optional)'),
                        ),
                        if (portfolioProof?.url != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Profile portfolio link on file: ${portfolioProof!.url}',
                                style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5)),
                          ),
                      ],
                    ),
                    FormSectionCard(
                      icon: Icons.mail_outline_rounded,
                      title: 'Cover letter',
                      subtitle: job.coverLetterRequired ? 'Required' : 'Optional',
                      children: [
                        TextField(
                          controller: _coverLetterController,
                          maxLines: 5,
                          style: const TextStyle(color: HomeStyle.textPrimary),
                          decoration: darkInputDecoration('Tell them why you\'re a great fit'),
                        ),
                      ],
                    ),
                    if (questions.isNotEmpty)
                      FormSectionCard(
                        icon: Icons.quiz_outlined,
                        title: 'Additional questions',
                        children: [
                          for (final q in questions) _QuestionField(question: q, controllers: _questionControllers, yesNoAnswers: _yesNoAnswers),
                        ],
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () {
                          if (_validate(job, questions)) setState(() => _reviewing = true);
                        },
                        child: const Text('Review application'),
                      ),
                    ),
                  ],
                ),
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

class _FilePickerTile extends StatelessWidget {
  const _FilePickerTile({required this.label, required this.fileName, required this.onTap});
  final String label;
  final String? fileName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.upload_file_rounded, size: 18, color: HomeStyle.purple),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fileName ?? label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fileName != null ? HomeStyle.textPrimary : HomeStyle.textSecondary,
                      fontWeight: fileName != null ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18, color: HomeStyle.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionField extends StatelessWidget {
  const _QuestionField({required this.question, required this.controllers, required this.yesNoAnswers});

  final JobApplicationQuestion question;
  final Map<String, TextEditingController> controllers;
  final Map<String, bool> yesNoAnswers;

  @override
  Widget build(BuildContext context) {
    final label = question.isRequired ? '${question.questionText} *' : question.questionText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: question.questionType == JobQuestionType.yesNo
          ? StatefulBuilder(
              builder: (context, setLocalState) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label, style: const TextStyle(color: HomeStyle.textPrimary, fontSize: 13.5)),
                value: yesNoAnswers[question.id] ?? false,
                onChanged: (v) => setLocalState(() => yesNoAnswers[question.id] = v),
              ),
            )
          : TextField(
              controller: controllers[question.id],
              maxLines: question.questionType == JobQuestionType.longAnswer ? 4 : 1,
              keyboardType: question.questionType == JobQuestionType.url ? TextInputType.url : TextInputType.text,
              style: const TextStyle(color: HomeStyle.textPrimary),
              decoration: darkInputDecoration(label),
            ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.job,
    required this.questions,
    required this.profile,
    required this.coverLetter,
    required this.resumeName,
    required this.portfolioName,
    required this.githubUrl,
    required this.linkedinUrl,
    required this.answers,
    required this.submitting,
    required this.onBack,
    required this.onSubmit,
  });

  final Job job;
  final List<JobApplicationQuestion> questions;
  final Profile? profile;
  final String coverLetter;
  final String? resumeName;
  final String? portfolioName;
  final String githubUrl;
  final String linkedinUrl;
  final Map<String, String> answers;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Applying to ${job.title} at ${job.companyName}',
              style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          FormSectionCard(
            icon: Icons.fact_check_outlined,
            title: 'Review',
            children: [
              _ReadOnlyRow(label: 'Applicant', value: profile?.displayName ?? '—'),
              if (resumeName != null) _ReadOnlyRow(label: 'Resume', value: resumeName!),
              if (portfolioName != null) _ReadOnlyRow(label: 'Portfolio', value: portfolioName!),
              if (githubUrl.isNotEmpty) _ReadOnlyRow(label: 'GitHub', value: githubUrl),
              if (linkedinUrl.isNotEmpty) _ReadOnlyRow(label: 'LinkedIn', value: linkedinUrl),
              if (coverLetter.isNotEmpty) _ReadOnlyRow(label: 'Cover letter', value: coverLetter),
              for (final entry in answers.entries)
                if (entry.value.isNotEmpty) _ReadOnlyRow(label: entry.key, value: entry.value),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: submitting ? null : onBack, child: const Text('Back')),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: submitting ? null : onSubmit,
                    child: submitting
                        ? const SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit application'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(gradient: HomeStyle.brandGradient, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              const Text('Application submitted!',
                  style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              const Text(
                'The recruiter will review your application. You can track its status from your applications.',
                textAlign: TextAlign.center,
                style: TextStyle(color: HomeStyle.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: onDone, child: const Text('Back to job')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
