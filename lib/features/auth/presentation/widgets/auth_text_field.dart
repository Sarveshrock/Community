import 'package:flutter/material.dart';

import 'auth_style.dart';

/// The glass-style input used by both auth screens. A thin wrapper around
/// [TextFormField] — every validation/behavior prop it takes is passed
/// straight through, so form logic (validators, controllers, focus, submit)
/// in the screens is completely unchanged; only the decoration is new.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.autovalidateMode,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffixIcon;
  final AutovalidateMode? autovalidateMode;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: _focused ? AuthStyle.glow(AuthStyle.blue, opacity: 0.18, blur: 16) : null,
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        validator: widget.validator,
        onFieldSubmitted: widget.onFieldSubmitted,
        autovalidateMode: widget.autovalidateMode,
        style: const TextStyle(color: AuthStyle.textPrimary, fontSize: 16),
        cursorColor: AuthStyle.blue,
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(color: _focused ? AuthStyle.textPrimary : AuthStyle.textMuted),
          floatingLabelStyle: const TextStyle(color: AuthStyle.textSecondary),
          prefixIcon: Icon(widget.icon, size: 21, color: _focused ? AuthStyle.blue : AuthStyle.textMuted),
          suffixIcon: widget.suffixIcon,
          filled: true,
          fillColor: AuthStyle.inputFill.withValues(alpha: 0.72),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AuthStyle.border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AuthStyle.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AuthStyle.borderFocused, width: 1.4),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AuthStyle.borderError, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AuthStyle.borderError, width: 1.4),
          ),
          errorStyle: const TextStyle(color: Color(0xFFFF9EC4), fontSize: 12.5),
        ),
      ),
    );
  }
}
