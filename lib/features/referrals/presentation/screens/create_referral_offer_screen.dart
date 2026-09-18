import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../home/presentation/widgets/home_style.dart';
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
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: HomeStyle.background,
        title: const Text('Offer a Referral',
            style: TextStyle(color: HomeStyle.textPrimary)),
        iconTheme: const IconThemeData(color: HomeStyle.textPrimary),
      ),
      body: ResponsiveCenter(
        maxWidth: 560,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Let other members request a referral from you at your company.',
                    style: TextStyle(
                        fontSize: 13, color: HomeStyle.textSecondary),
                  ),
                ),
                const SizedBox(height: 14),
                FormSectionCard(
                  icon: Icons.badge_outlined,
                  title: 'Referral details',
                  children: [
                    TextFormField(
                      controller: _companyController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration('Company'),
                      validator: (v) =>
                          Validators.required(v, fieldName: 'Company'),
                    ),
                    TextFormField(
                      controller: _roleController,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration(
                          'Roles you can refer for (optional)'),
                    ),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      style: const TextStyle(color: HomeStyle.textPrimary),
                      decoration: darkInputDecoration(
                          'Notes for requesters (optional)',
                          hint:
                              'e.g. Only for SDE roles, 2+ years experience'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: isSaving ? null : _submit,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: HomeStyle.brandGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Post offer',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                    ),
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
