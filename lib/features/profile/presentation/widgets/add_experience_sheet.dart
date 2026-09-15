import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../providers/profile_providers.dart';

class AddExperienceSheet extends ConsumerStatefulWidget {
  const AddExperienceSheet({super.key});

  @override
  ConsumerState<AddExperienceSheet> createState() => _AddExperienceSheetState();
}

class _AddExperienceSheetState extends ConsumerState<AddExperienceSheet> {
  final _companyController = TextEditingController();
  final _roleController = TextEditingController();
  EmploymentType _employmentType = EmploymentType.fullTime;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isCurrent = true;

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate != null && _endDate!.isBefore(_startDate)) _endDate = null;
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  Future<void> _submit() async {
    if (_companyController.text.trim().isEmpty ||
        _roleController.text.trim().isEmpty) return;
    final experience = Experience(
      id: '',
      companyName: _companyController.text.trim(),
      role: _roleController.text.trim(),
      employmentType: _employmentType,
      startDate: _startDate,
      endDate: _isCurrent ? null : _endDate,
      isCurrent: _isCurrent,
    );
    final success = await ref
        .read(profileControllerProvider.notifier)
        .addExperience(experience);
    if (success && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _companyController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add experience',
              style: context.textStyles.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
              controller: _roleController,
              decoration: const InputDecoration(labelText: 'Role')),
          const SizedBox(height: 12),
          TextField(
              controller: _companyController,
              decoration: const InputDecoration(labelText: 'Company')),
          const SizedBox(height: 12),
          DropdownButtonFormField<EmploymentType>(
            initialValue: _employmentType,
            decoration: const InputDecoration(labelText: 'Employment type'),
            items: [
              for (final type in EmploymentType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: (v) =>
                setState(() => _employmentType = v ?? _employmentType),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start date'),
            subtitle: Text(DateFormat.yMMM().format(_startDate)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _pickStartDate,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('I currently work here'),
            value: _isCurrent,
            onChanged: (v) => setState(() => _isCurrent = v),
          ),
          if (!_isCurrent)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End date'),
              subtitle: Text(_endDate != null
                  ? DateFormat.yMMM().format(_endDate!)
                  : 'Select end date'),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: _pickEndDate,
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _submit, child: const Text('Add')),
          ),
        ],
      ),
    );
  }
}
