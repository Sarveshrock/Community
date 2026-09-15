import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_background.dart';
import '../widgets/auth_footer.dart';
import '../widgets/auth_gradient_button.dart';
import '../widgets/auth_headline.dart';
import '../widgets/auth_style.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/communeo_logo.dart';
import '../widgets/decorative_message.dart';
import '../widgets/social_auth_button.dart';

/// Sign-up UI only. Fields are exactly Email / Password / Confirm password —
/// there has never been a Full Name field here: `AuthController.signUp()`
/// and `AuthRepositoryImpl.signUpWithEmail()` take only email/password, so
/// there's nothing backend-required to preserve a name field for. A display
/// name, if the app collects one at all, belongs to onboarding — untouched
/// by this redesign.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final success = await ref.read(authControllerProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (success && mounted) {
      context.showSnack('Check your email to confirm your account.');
      context.pop();
    } else if (mounted) {
      final error = ref.read(authControllerProvider).error;
      context.showSnack(error?.toString() ?? 'Sign up failed', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(authControllerProvider);
    final isLoading = controllerState.isLoading;

    return Scaffold(
      backgroundColor: AuthStyle.background,
      body: Stack(
        children: [
          const AuthBackground(),
          const Positioned(
            top: 130,
            right: 20,
            child: DecorativeMessage(
              'Connect\nLearn\nGrow\nTogether.',
              fontSize: 17,
              textAlign: TextAlign.right,
            ),
          ),
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const CommuneoBrandHeader(),
                            const SizedBox(height: 28),
                            const AuthHeadline(firstLine: 'Create your', accentLine: 'account'),
                            const SizedBox(height: 10),
                            const Text(
                              'Tell us what you want to do, and we\'ll help you find the right people.',
                              style: TextStyle(color: AuthStyle.textSecondary, fontSize: 14.5, height: 1.4),
                            ),
                            const SizedBox(height: 28),
                            AuthTextField(
                              controller: _emailController,
                              label: 'Email',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: Validators.email,
                            ),
                            const SizedBox(height: 14),
                            AuthTextField(
                              controller: _passwordController,
                              label: 'Password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              validator: Validators.password,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AuthStyle.textMuted,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            const SizedBox(height: 14),
                            AuthTextField(
                              controller: _confirmController,
                              label: 'Confirm password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscureConfirm,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: (value) {
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AuthStyle.textMuted,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                            const SizedBox(height: 24),
                            AuthGradientButton(
                              label: 'Create account',
                              isLoading: isLoading,
                              onPressed: isLoading ? null : _submit,
                            ),
                            const SizedBox(height: 26),
                            const Row(
                              children: [
                                Expanded(child: Divider(color: AuthStyle.border)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('or sign up with',
                                      style: TextStyle(color: AuthStyle.textMuted, fontSize: 12.5)),
                                ),
                                Expanded(child: Divider(color: AuthStyle.border)),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: SocialAuthButton(
                                    icon: const GoogleLogoMark(),
                                    label: 'Google',
                                    onPressed: isLoading
                                        ? null
                                        : () =>
                                            ref.read(authControllerProvider.notifier).signInWithGoogle(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SocialAuthButton(
                                    icon: const Icon(Icons.apple, color: Colors.white, size: 22),
                                    label: 'Apple',
                                    onPressed: isLoading
                                        ? null
                                        : () =>
                                            ref.read(authControllerProvider.notifier).signInWithApple(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            AuthFooter(
                              prompt: 'Already have an account?',
                              actionLabel: 'Sign in',
                              onTap: isLoading ? null : () => context.pop(),
                            ),
                          ],
                        ),
                      ),
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
}
