import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/form_section_card.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/startup_providers.dart';

class AddOpportunitySheet extends ConsumerStatefulWidget {
  const AddOpportunitySheet({super.key, required this.startupId});
  final String startupId;

  @override
  ConsumerState<AddOpportunitySheet> createState() =>
      _AddOpportunitySheetState();
}

class _AddOpportunitySheetState extends ConsumerState<AddOpportunitySheet> {
  final _titleController = TextEditingController();
  final _roleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isRemote = true;

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) return;
    final success = await ref
        .read(startupControllerProvider.notifier)
        .createOpportunity(widget.startupId, {
      'title': _titleController.text.trim(),
      'role': _roleController.text.trim().isEmpty
          ? null
          : _roleController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'is_remote': _isRemote,
    });
    if (success && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _roleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add an open role',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HomeStyle.textPrimary)),
          const SizedBox(height: 16),
          TextField(
              controller: _titleController,
              style: const TextStyle(color: HomeStyle.textPrimary),
              decoration: darkInputDecoration('Title')),
          const SizedBox(height: 12),
          TextField(
              controller: _roleController,
              style: const TextStyle(color: HomeStyle.textPrimary),
              decoration:
                  darkInputDecoration('Role (e.g. Co-founder, Designer)')),
          const SizedBox(height: 12),
          TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(color: HomeStyle.textPrimary),
              decoration: darkInputDecoration('Description')),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(
                child: Text('Remote',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: HomeStyle.textPrimary)),
              ),
              Switch(
                value: _isRemote,
                onChanged: (v) => setState(() => _isRemote = v),
                activeThumbColor: Colors.white,
                activeTrackColor: HomeStyle.purple,
                inactiveThumbColor: HomeStyle.textSecondary,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _submit,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: HomeStyle.brandGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('Add',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
