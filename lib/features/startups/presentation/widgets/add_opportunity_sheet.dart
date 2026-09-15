import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
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
          Text('Add an open role',
              style: context.textStyles.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(
              controller: _roleController,
              decoration: const InputDecoration(
                  labelText: 'Role (e.g. Co-founder, Designer)')),
          const SizedBox(height: 12),
          TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Remote'),
            value: _isRemote,
            onChanged: (v) => setState(() => _isRemote = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child:
                  FilledButton(onPressed: _submit, child: const Text('Add'))),
        ],
      ),
    );
  }
}
