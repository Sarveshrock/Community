import 'package:flutter/material.dart';

import 'auth_style.dart';

/// "New to Communeo? Create an account" / "Already have an account? Sign
/// in" — a plain prompt followed by an accent-colored action, both on one
/// tappable row. [onTap] is whatever navigation call the screen already
/// makes (e.g. `context.push(RoutePaths.signUp)`); unchanged here.
class AuthFooter extends StatelessWidget {
  const AuthFooter({
    super.key,
    required this.prompt,
    required this.actionLabel,
    required this.onTap,
  });

  final String prompt;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text.rich(
          TextSpan(
            text: '$prompt ',
            style: const TextStyle(color: AuthStyle.textSecondary, fontSize: 14.5),
            children: [
              TextSpan(
                text: actionLabel,
                style: const TextStyle(
                  color: AuthStyle.cyan,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
