import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
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

/// Sign-in UI only — form state, validation and the calls into
/// [AuthController] are unchanged from before this redesign.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final success = await ref.read(authControllerProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!success && mounted) {
      final error = ref.read(authControllerProvider).error;
      context.showSnack(error?.toString() ?? 'Sign in failed', isError: true);
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
            top: 90,
            right: 22,
            child: DecorativeMessage(
              'Same People.\nBigger\nPossibilities.',
              fontSize: 17,
              textAlign: TextAlign.right,
            ),
          ),
          Positioned(
            left: 24,
            bottom: 34,
            child: DecorativeMessage(
              'A Brighter\nNetwork for a\nBigger Tomorrow.',
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          SafeArea(
            child: Center(
              child: ResponsiveCenter(
                maxWidth: 430,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const CommuneoBrandHeader(),
                        const SizedBox(height: 28),
                        const AuthHeadline(firstLine: 'Welcome', accentLine: 'back!'),
                        const SizedBox(height: 10),
                        const Text(
                          'Sign in to keep finding the right people and opportunities.',
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
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          validator: Validators.password,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AuthStyle.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: isLoading ? null : () => context.push('/forgot-password'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              foregroundColor: AuthStyle.cyan,
                            ),
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AuthGradientButton(
                          label: 'Sign in',
                          isLoading: isLoading,
                          onPressed: isLoading ? null : _submit,
                        ),
                        const SizedBox(height: 26),
                        const Row(
                          children: [
                            Expanded(child: Divider(color: AuthStyle.border)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('or continue with',
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
                                    : () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SocialAuthButton(
                                icon: const Icon(Icons.apple, color: Colors.white, size: 22),
                                label: 'Apple',
                                onPressed: isLoading
                                    ? null
                                    : () => ref.read(authControllerProvider.notifier).signInWithApple(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        AuthFooter(
                          prompt: 'New to ${AppConstants.appName}?',
                          actionLabel: 'Create an account',
                          onTap: isLoading ? null : () => context.push('/sign-up'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
