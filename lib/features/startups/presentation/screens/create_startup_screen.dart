import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../providers/startup_providers.dart';

const _stages = ['idea', 'mvp', 'early_revenue', 'growth', 'funded'];

class CreateStartupScreen extends ConsumerStatefulWidget {
  const CreateStartupScreen({super.key});

  @override
  ConsumerState<CreateStartupScreen> createState() =>
      _CreateStartupScreenState();
}

class _CreateStartupScreenState extends ConsumerState<CreateStartupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _industryController = TextEditingController();
  final _websiteController = TextEditingController();
  String _stage = 'idea';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success =
        await ref.read(startupControllerProvider.notifier).createStartup({
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'industry': _industryController.text.trim().isEmpty
          ? null
          : _industryController.text.trim(),
      'website': _websiteController.text.trim().isEmpty
          ? null
          : _websiteController.text.trim(),
      'stage': _stage,
    });
    if (success && mounted) {
      context.pop();
    } else if (mounted) {
      context.showSnack('Could not create startup', isError: true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _industryController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(startupControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('New Startup')),
      body: ResponsiveCenter(
        maxWidth: 560,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Startup name'),
                  validator: (v) => Validators.required(v, fieldName: 'Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _industryController,
                    decoration: const InputDecoration(labelText: 'Industry')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _websiteController,
                    decoration: const InputDecoration(labelText: 'Website'),
                    validator: Validators.url),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _stage,
                  decoration: const InputDecoration(labelText: 'Stage'),
                  items: [
                    for (final s in _stages)
                      DropdownMenuItem(
                          value: s, child: Text(s.replaceAll('_', ' ')))
                  ],
                  onChanged: (v) => setState(() => _stage = v ?? _stage),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isSaving ? null : _submit,
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Create startup'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
