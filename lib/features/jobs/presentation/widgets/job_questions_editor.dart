import 'package:flutter/material.dart';

import '../../../../core/widgets/form_section_card.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../domain/entities/job_application_question.dart';

/// The Job Builder's "Custom application questions" list — recruiter-defined
/// questions shown to applicants during the internal apply flow. Placeholder
/// ids/jobIds are fine here (real ones are assigned server-side on create —
/// `toInsertJson` never reads them back), mirroring `AgendaEditor`'s pattern.
class JobQuestionsEditor extends StatelessWidget {
  const JobQuestionsEditor({super.key, required this.questions, required this.onChanged});

  final List<JobApplicationQuestion> questions;
  final ValueChanged<List<JobApplicationQuestion>> onChanged;

  Future<void> _addQuestion(BuildContext context) async {
    final question = await showModalBottomSheet<JobApplicationQuestion>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeStyle.cardBase,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _AddQuestionSheet(),
    );
    if (question == null) return;
    onChanged([...questions, question.copyWithOrder(questions.length)]);
  }

  void _remove(int index) {
    final next = [...questions]..removeAt(index);
    onChanged([for (var i = 0; i < next.length; i++) next[i].copyWithOrder(i)]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < questions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _QuestionTile(question: questions[i], onRemove: () => _remove(i)),
          ),
        OutlinedButton.icon(
          onPressed: () => _addQuestion(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add question'),
          style: OutlinedButton.styleFrom(
            foregroundColor: HomeStyle.purple,
            side: BorderSide(color: HomeStyle.purple.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }
}

extension on JobApplicationQuestion {
  JobApplicationQuestion copyWithOrder(int order) => JobApplicationQuestion(
        id: id,
        jobId: jobId,
        questionText: questionText,
        questionType: questionType,
        isRequired: isRequired,
        sortOrder: order,
      );
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.question, required this.onRemove});

  final JobApplicationQuestion question;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question.questionText,
                    style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(
                  '${question.questionType.label}${question.isRequired ? ' · Required' : ''}',
                  style: const TextStyle(fontSize: 12, color: HomeStyle.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: HomeStyle.textSecondary),
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AddQuestionSheet extends StatefulWidget {
  const _AddQuestionSheet();

  @override
  State<_AddQuestionSheet> createState() => _AddQuestionSheetState();
}

class _AddQuestionSheetState extends State<_AddQuestionSheet> {
  final _textController = TextEditingController();
  JobQuestionType _type = JobQuestionType.shortAnswer;
  bool _required = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _save() {
    if (_textController.text.trim().isEmpty) return;
    Navigator.of(context).pop(JobApplicationQuestion(
      id: '',
      jobId: '',
      questionText: _textController.text.trim(),
      questionType: _type,
      isRequired: _required,
      sortOrder: 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add question', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            style: const TextStyle(color: HomeStyle.textPrimary),
            decoration: darkInputDecoration('Question'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<JobQuestionType>(
            isExpanded: true,
            initialValue: _type,
            dropdownColor: HomeStyle.cardBase,
            style: const TextStyle(color: HomeStyle.textPrimary),
            decoration: darkInputDecoration('Answer type'),
            items: [for (final t in JobQuestionType.values) DropdownMenuItem(value: t, child: Text(t.label))],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Required', style: TextStyle(color: HomeStyle.textPrimary)),
            value: _required,
            onChanged: (v) => setState(() => _required = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: const Text('Add question')),
          ),
        ],
      ),
    );
  }
}
