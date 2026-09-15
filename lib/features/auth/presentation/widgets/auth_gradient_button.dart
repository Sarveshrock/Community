import 'package:flutter/material.dart';

import 'auth_style.dart';

/// The primary "Sign in" / "Create account" CTA: full-width blue -> purple
/// gradient pill with a trailing arrow and a built-in loading spinner state.
/// Purely presentational — [onPressed] is whatever the caller passes (the
/// screen's existing submit handler); this widget never decides what
/// happens on tap.
class AuthGradientButton extends StatefulWidget {
  const AuthGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  State<AuthGradientButton> createState() => _AuthGradientButtonState();
}

class _AuthGradientButtonState extends State<AuthGradientButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: AuthStyle.ctaGradient,
            boxShadow: _enabled
                ? AuthStyle.glow(AuthStyle.blue, opacity: 0.35, blur: 20, spread: -4)
                : null,
          ),
          child: Opacity(
            opacity: _enabled || widget.isLoading ? 1 : 0.55,
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
