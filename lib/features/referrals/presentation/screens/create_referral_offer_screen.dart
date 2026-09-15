import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/referral_providers.dart';

class CreateReferralOfferScreen extends ConsumerStatefulWidget {
  const CreateReferralOfferScreen({super.key});

  @override
  ConsumerState<CreateReferralOfferScreen> createState() =>
      _CreateReferralOfferScreenState();
}

class _CreateReferralOfferScreenState
    extends ConsumerState<CreateReferralOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _roleController = TextEditingController();
  final _notesController = TextEditingController();
  bool _prefilled = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(referralControllerProvider.notifier).createOffer({
      'company_name': _companyController.text.trim(),
      'role_title':
          _roleController.text.trim().isEmpty ? null : _roleController.text.trim(),
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    });
    if (success && mounted) {
      context.pop();
    } else if (mounted) {
      context.showSnack('Could not save this offer', isError: true);
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _roleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(referralControllerProvider).isLoading;
    final profileAsync = ref.watch(myProfileProvider);

    profileAsync.whenData((profile) {
      if (!_prefilled && profile?.currentCompany != null) {
        _companyController.text = profile!.currentCompany!;
        _prefilled = true;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Offer a Referral')),
      body: ResponsiveCenter(
        maxWidth: 560,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Let other members request a referral from you at your company.',
                  style: context.textStyles.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _companyController,
                  decoration: const InputDecoration(labelText: 'Company'),
                  validator: (v) => Validators.required(v, fieldName: 'Company'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _roleController,
                  decoration: const InputDecoration(
                      labelText: 'Roles you can refer for (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes for requesters (optional)',
                    hintText: 'e.g. Only for SDE roles, 2+ years experience',
                    alignLabelWithHint: true,
                  ),
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
                        : const Text('Post offer'),
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
