import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/utils/formatters.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../domain/entities/job.dart';

/// Compact discovery-list card for a job — logo, title, company, type/mode,
/// location, salary (if visible), top skill chips, posted date.
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final topSkills = job.requiredSkillNames.take(3).toList();
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HomeStyle.cardBase,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: job.companyLogoUrl == null ? HomeStyle.brandGradient : null,
                      image: job.companyLogoUrl != null
                          ? DecorationImage(image: NetworkImage(job.companyLogoUrl!), fit: BoxFit.cover)
                          : null,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: job.companyLogoUrl == null
                        ? Text(job.companyName.isEmpty ? '?' : job.companyName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(job.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(job.companyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: HomeStyle.purple, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Text(timeago.format(job.createdAt.toLocal()),
                      style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Badge(job.employmentType.label),
                  _Badge(job.workMode.label),
                  if ((job.location ?? job.city) != null) _Badge(job.location ?? job.city!),
                ],
              ),
              if (job.hasCompensationInfo) ...[
                const SizedBox(height: 10),
                Text(
                  '${Formatters.salaryRange(job.salaryMin, job.salaryMax, job.currency)}'
                  '${job.payPeriod != null ? ' ${job.payPeriod!.label}' : ''}',
                  style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
              if (topSkills.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final skill in topSkills)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: HomeStyle.cyan.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(skill, style: const TextStyle(fontSize: 11, color: HomeStyle.cyan, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10.5, color: HomeStyle.textSecondary, fontWeight: FontWeight.w600)),
    );
  }
}
