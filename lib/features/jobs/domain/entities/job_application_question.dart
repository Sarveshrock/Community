enum JobQuestionType { shortAnswer, longAnswer, yesNo, url }

extension JobQuestionTypeX on JobQuestionType {
  String get value => switch (this) {
        JobQuestionType.shortAnswer => 'short_answer',
        JobQuestionType.longAnswer => 'long_answer',
        JobQuestionType.yesNo => 'yes_no',
        JobQuestionType.url => 'url',
      };

  String get label => switch (this) {
        JobQuestionType.shortAnswer => 'Short answer',
        JobQuestionType.longAnswer => 'Long answer',
        JobQuestionType.yesNo => 'Yes / No',
        JobQuestionType.url => 'URL',
      };

  static JobQuestionType fromValue(String? value) => JobQuestionType.values
      .firstWhere((e) => e.value == value, orElse: () => JobQuestionType.shortAnswer);
}

/// A recruiter-defined custom application question (`job_application_questions`)
/// — collected once during Post a Job, shown automatically to every
/// applicant during the internal application flow. Never a disconnected
/// question system: it's read by the same `job_id` the job itself uses.
class JobApplicationQuestion {
  const JobApplicationQuestion({
    required this.id,
    required this.jobId,
    required this.questionText,
    this.questionType = JobQuestionType.shortAnswer,
    this.isRequired = false,
    this.sortOrder = 0,
  });

  final String id;
  final String jobId;
  final String questionText;
  final JobQuestionType questionType;
  final bool isRequired;
  final int sortOrder;

  factory JobApplicationQuestion.fromJson(Map<String, dynamic> json) => JobApplicationQuestion(
        id: json['id'] as String,
        jobId: json['job_id'] as String,
        questionText: json['question_text'] as String,
        questionType: JobQuestionTypeX.fromValue(json['question_type'] as String?),
        isRequired: json['is_required'] as bool? ?? false,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toInsertJson(String jobId) => {
        'job_id': jobId,
        'question_text': questionText,
        'question_type': questionType.value,
        'is_required': isRequired,
        'sort_order': sortOrder,
      };
}
