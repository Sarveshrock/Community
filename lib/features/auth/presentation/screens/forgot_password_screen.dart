import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_background.dart';
import '../widgets/auth_gradient_button.dart';
import '../widgets/auth_headline.dart';
import '../widgets/auth_style.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/communeo_logo.dart';

/// Visual-only redesign to match Sign In / Sign Up's [AuthStyle] premium
/// dark brand moment — this was the one screen in the auth flow still on
/// plain default Material, a visible drop the instant a user tapped
/// "Forgot password?". Form state, validation, and the
/// `sendPasswordReset` call are unchanged.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_emailController.text.trim());
    if (success && mounted) {
      setState(() => _sent = true);
    } else if (mounted) {
      context.showSnack('Could not send reset email. Try again.',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: AuthStyle.background,
      body: Stack(
        children: [
          const AuthBackground(),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 4,
                  left: 4,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AuthStyle.textPrimary),
                    onPressed: isLoading ? null : () => context.pop(),
                  ),
                ),
                Center(
                  child: ResponsiveCenter(
                    maxWidth: 430,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 44, 20, 20),
                      child: _sent ? _SentConfirmation(email: _emailController.text.trim()) : _buildForm(isLoading),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CommuneoBrandHeader(),
          const SizedBox(height: 28),
          const AuthHeadline(firstLine: 'Reset your', accentLine: 'password'),
          const SizedBox(height: 10),
          const Text(
            'Enter the email associated with your account and we\'ll send a reset link.',
            style: TextStyle(color: AuthStyle.textSecondary, fontSize: 14.5, height: 1.4),
          ),
          const SizedBox(height: 28),
          AuthTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: Validators.email,
          ),
          const SizedBox(height: 24),
          AuthGradientButton(
            label: 'Send reset link',
            isLoading: isLoading,
            onPressed: isLoading ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _SentConfirmation extends StatelessWidget {
  const _SentConfirmation({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(gradient: AuthStyle.brandGradient, shape: BoxShape.circle),
          child: const Icon(Icons.mark_email_read_outlined, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 24),
        const Text('Check your inbox',
            style: TextStyle(color: AuthStyle.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(
          'We sent a password reset link to $email.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AuthStyle.textSecondary, fontSize: 14.5, height: 1.4),
        ),
        const SizedBox(height: 28),
        AuthGradientButton(
          label: 'Back to sign in',
          onPressed: () => context.go('/sign-in'),
        ),
      ],
    );
  }
}
