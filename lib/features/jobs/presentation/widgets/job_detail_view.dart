import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/formatters.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../domain/entities/job.dart';
import '../../domain/job_action_state.dart';

/// The job's full rendering — shared by the real, provider-backed
/// `JobDetailScreen` and the create-flow's live Preview step, so the two
/// can never visually drift apart. Every dynamic bit (apply action,
/// organizer controls) is passed in rather than fetched here.
///
/// Every optional section is conditionally rendered only when the job
/// actually has that data — an old job (posted before this redesign) with
/// only the original 9 fields renders exactly as it always did, with every
/// new section simply absent, never a blank space or a literal "null".
class JobDetailView extends StatelessWidget {
  const JobDetailView({
    super.key,
    required this.job,
    this.actionState,
    this.onPrimaryAction,
    this.isActionLoading = false,
    this.organizerControls,
    this.logoBytesPreview,
  });

  final Job job;

  /// Null in preview mode — shows a static "Preview" badge instead of a
  /// real CTA.
  final JobActionState? actionState;
  final VoidCallback? onPrimaryAction;
  final bool isActionLoading;
  final Widget? organizerControls;
  final ImageProvider? logoBytesPreview;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (job.isClosed || job.isFilled) _StatusBanner(job: job),
        _Header(job: job, logoOverride: logoBytesPreview),
        const SizedBox(height: 18),
        _PrimaryActionRow(actionState: actionState, onPrimaryAction: onPrimaryAction, isLoading: isActionLoading),
        const SizedBox(height: 18),
        _QuickInfoGrid(job: job),
        const SizedBox(height: 20),
        if ((job.description ?? '').isNotEmpty) ...[
          const _SectionHeader('About the role'),
          Text(job.description!, style: const TextStyle(color: HomeStyle.textSecondary, height: 1.5)),
          const SizedBox(height: 20),
        ],
        if (job.responsibilities.isNotEmpty) ...[
          const _SectionHeader('Responsibilities'),
          _CheckList(items: job.responsibilities),
          const SizedBox(height: 20),
        ],
        if (_hasRequirements(job)) ...[
          const _SectionHeader('Requirements'),
          _RequirementsBlock(job: job),
          if (job.requiredSkillNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ChipWrap(items: job.requiredSkillNames, accent: HomeStyle.purple),
          ],
          const SizedBox(height: 20),
        ],
        if (job.preferredSkillNames.isNotEmpty) ...[
          const _SectionHeader('Nice to have'),
          _ChipWrap(items: job.preferredSkillNames, accent: HomeStyle.cyan),
          const SizedBox(height: 20),
        ],
        if (_hasCompensationDetail(job)) ...[
          const _SectionHeader('Compensation'),
          _CompensationBlock(job: job),
          const SizedBox(height: 20),
        ],
        if (job.benefits.isNotEmpty) ...[
          const _SectionHeader('Benefits'),
          _CheckList(items: job.benefits),
          const SizedBox(height: 20),
        ],
        const _SectionHeader('Location'),
        _LocationSection(job: job),
        if (_hasCompanyInfo(job)) ...[
          const SizedBox(height: 20),
          const _SectionHeader('About the company'),
          _CompanyCard(job: job),
        ],
        const SizedBox(height: 20),
        const _SectionHeader('Application information'),
        _ApplicationInfoBlock(job: job),
        if (organizerControls != null) ...[
          const SizedBox(height: 20),
          organizerControls!,
        ],
      ],
    );
  }
}

bool _hasRequirements(Job job) =>
    job.experienceMinMonths != null ||
    job.experienceMaxMonths != null ||
    job.experienceLevel != null ||
    (job.education ?? '').isNotEmpty ||
    (job.prerequisites ?? '').isNotEmpty ||
    job.requiredSkillNames.isNotEmpty;

bool _hasCompensationDetail(Job job) =>
    job.hasCompensationInfo || (job.bonusInfo ?? '').isNotEmpty || (job.equityInfo ?? '').isNotEmpty;

bool _hasCompanyInfo(Job job) =>
    job.companyLogoUrl != null || job.companyWebsite != null || (job.companyDescription ?? '').isNotEmpty;

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    final label = job.isFilled ? 'This position has been filled.' : 'This job is no longer accepting applications.';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFB7185).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFB7185).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFFB7185), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(color: Color(0xFFFB7185), fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.job, this.logoOverride});
  final Job job;
  final ImageProvider? logoOverride;

  @override
  Widget build(BuildContext context) {
    final logo = logoOverride ?? (job.companyLogoUrl != null ? NetworkImage(job.companyLogoUrl!) : null);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: logo == null ? HomeStyle.brandGradient : null,
            image: logo != null ? DecorationImage(image: logo, fit: BoxFit.cover) : null,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: logo == null
              ? Text(job.companyName.isEmpty ? '?' : job.companyName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22))
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(job.title,
                  style: const TextStyle(color: HomeStyle.textPrimary, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(job.companyName, style: const TextStyle(color: HomeStyle.purple, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MetaBadge(job.employmentType.label),
                  _MetaBadge(job.workMode.label),
                  if ((job.location ?? job.city) != null) _MetaBadge(job.location ?? job.city!),
                ],
              ),
              if (job.hasCompensationInfo) ...[
                const SizedBox(height: 8),
                Text(
                  '${Formatters.salaryRange(job.salaryMin, job.salaryMax, job.currency)}'
                  '${job.payPeriod != null ? ' ${job.payPeriod!.label}' : ''}',
                  style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11.5, color: HomeStyle.textSecondary, fontWeight: FontWeight.w600)),
    );
  }
}

class _PrimaryActionRow extends StatelessWidget {
  const _PrimaryActionRow({required this.actionState, required this.onPrimaryAction, required this.isLoading});

  final JobActionState? actionState;
  final VoidCallback? onPrimaryAction;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (actionState == null) {
      return Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: const Text('Preview — actions are disabled',
            style: TextStyle(color: HomeStyle.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
      );
    }
    if (actionState == JobActionState.owner || actionState == JobActionState.none) {
      return const SizedBox.shrink();
    }

    final state = actionState!;
    final enabled = state.isActionable && !isLoading;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: enabled ? onPrimaryAction : null,
          child: Container(
            decoration: BoxDecoration(
              gradient: enabled ? HomeStyle.brandGradient : null,
              color: enabled ? null : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(100),
              boxShadow: enabled ? HomeStyle.glow(HomeStyle.purple, opacity: 0.3) : null,
            ),
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(state.label,
                    style: TextStyle(
                        color: enabled ? Colors.white : HomeStyle.textSecondary, fontWeight: FontWeight.w700, fontSize: 14.5)),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
    );
  }
}

class _QuickInfoGrid extends StatelessWidget {
  const _QuickInfoGrid({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (Icons.work_outline_rounded, 'Employment', job.employmentType.label),
      (Icons.public_rounded, 'Work mode', job.workMode.label),
      if ((job.location ?? job.city) != null) (Icons.place_outlined, 'Location', job.location ?? job.city!),
      if (job.experienceLevel != null) (Icons.trending_up_rounded, 'Level', job.experienceLevel!.jobLabel),
      if (job.hasCompensationInfo)
        (Icons.payments_outlined, 'Salary',
            '${Formatters.salaryRange(job.salaryMin, job.salaryMax, job.currency)}${job.payPeriod != null ? ' ${job.payPeriod!.label}' : ''}'),
      if (job.deadline != null) (Icons.event_busy_outlined, 'Deadline', DateFormat.yMMMd().format(job.deadline!.toLocal())),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        for (final (icon, label, value) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: HomeStyle.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 10.5, color: HomeStyle.textSecondary)),
                      Text(value,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CheckList extends StatelessWidget {
  const _CheckList({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10D9A0)),
                const SizedBox(width: 8),
                Expanded(child: Text(item, style: const TextStyle(color: HomeStyle.textSecondary, height: 1.4))),
              ],
            ),
          ),
      ],
    );
  }
}

class _RequirementsBlock extends StatelessWidget {
  const _RequirementsBlock({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (job.experienceMinMonths != null || job.experienceMaxMonths != null)
        (
          'Experience',
          job.experienceMinMonths != null && job.experienceMaxMonths != null
              ? '${Formatters.experienceFromMonths(job.experienceMinMonths!)} – ${Formatters.experienceFromMonths(job.experienceMaxMonths!)}'
              : Formatters.experienceFromMonths(job.experienceMinMonths ?? job.experienceMaxMonths ?? 0),
        ),
      if (job.experienceLevel != null) ('Level', job.experienceLevel!.jobLabel),
      if ((job.education ?? '').isNotEmpty) ('Education', job.education!),
      if ((job.prerequisites ?? '').isNotEmpty) ('Prerequisites', job.prerequisites!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: HomeStyle.textSecondary, height: 1.4),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
      ],
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

class _CompensationBlock extends StatelessWidget {
  const _CompensationBlock({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (job.hasCompensationInfo)
          Text(
            '${Formatters.salaryRange(job.salaryMin, job.salaryMax, job.currency)}${job.payPeriod != null ? ' ${job.payPeriod!.label}' : ''}',
            style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        if (job.salaryNegotiable) ...[
          const SizedBox(height: 4),
          const Text('Negotiable', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
        ],
        if ((job.bonusInfo ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Bonus: ${job.bonusInfo}', style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
        ],
        if ((job.equityInfo ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Equity: ${job.equityInfo}', style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
        ],
        if (job.isInternship && job.stipend != null) ...[
          const SizedBox(height: 4),
          Text('Stipend: ${Formatters.currency(job.stipend, job.currency)}',
              style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
        ],
      ],
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(job.workMode == WorkMode.remote ? Icons.public_rounded : Icons.place_outlined,
                  size: 18, color: HomeStyle.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  job.workMode == WorkMode.remote ? 'Remote' : (job.location ?? job.city ?? 'Location to be shared'),
                  style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (job.workMode != WorkMode.remote && (job.city ?? job.state) != null) ...[
            const SizedBox(height: 4),
            Text([job.city, job.state, job.country].whereType<String>().join(', '),
                style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
          ],
          if (job.workMode == WorkMode.hybrid && (job.expectedOfficeDays ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('In-office: ${job.expectedOfficeDays}', style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: job.companyLogoUrl == null ? HomeStyle.brandGradient : null,
                  image: job.companyLogoUrl != null
                      ? DecorationImage(image: NetworkImage(job.companyLogoUrl!), fit: BoxFit.cover)
                      : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: job.companyLogoUrl == null
                    ? Text(job.companyName.isEmpty ? '?' : job.companyName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(job.companyName,
                    style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ],
          ),
          if ((job.companyDescription ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(job.companyDescription!, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5, height: 1.4)),
          ],
          if ((job.companyWebsite ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(job.companyWebsite!, style: const TextStyle(color: HomeStyle.purple, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}

class _ApplicationInfoBlock extends StatelessWidget {
  const _ApplicationInfoBlock({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    final requirements = <String>[
      if (job.resumeRequired) 'Resume required',
      if (job.portfolioRequired) 'Portfolio required',
      if (job.coverLetterRequired) 'Cover letter required',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.isInternalApplication ? 'Apply directly on Communeo.' : 'Apply on the employer\'s own site.',
            style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (job.deadline != null) ...[
            const SizedBox(height: 6),
            Text('Applications close on ${DateFormat.yMMMd().format(job.deadline!.toLocal())}',
                style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
          ],
          if (requirements.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(requirements.join(' · '), style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
          ],
          if ((job.applicationInstructions ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(job.applicationInstructions!, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5, height: 1.4)),
          ],
          if ((job.contactInfo ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Contact: ${job.contactInfo}', style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}
