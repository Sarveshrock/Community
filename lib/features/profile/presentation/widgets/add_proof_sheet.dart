import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../providers/profile_providers.dart';

class AddProofSheet extends ConsumerStatefulWidget {
  const AddProofSheet({super.key});

  @override
  ConsumerState<AddProofSheet> createState() => _AddProofSheetState();
}

class _AddProofSheetState extends ConsumerState<AddProofSheet> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  ProofType _proofType = ProofType.github;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final proof = OptionalProof(
      id: '',
      proofType: _proofType,
      url: _urlController.text.trim(),
      title: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
    );
    final success = await ref
        .read(profileControllerProvider.notifier)
        .addOptionalProof(proof);
    if (success && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add proof of skill',
                style: context.textStyles.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Optional',
                style: context.textStyles.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant)),
            const SizedBox(height: 16),
            DropdownButtonFormField<ProofType>(
              initialValue: _proofType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final type in ProofType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (v) => setState(() => _proofType = v ?? _proofType),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'URL'),
              validator: Validators.url,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _submit, child: const Text('Add')),
            ),
          ],
        ),
      ),
    );
  }
}
