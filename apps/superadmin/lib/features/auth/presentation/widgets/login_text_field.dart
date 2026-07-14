import 'package:flutter/material.dart';

class LoginTextField extends StatefulWidget {
  const LoginTextField({
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    required this.validator,
    required this.enabled,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.suffixIcon,
    this.onFieldSubmitted,
    super.key,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final FormFieldValidator<String> validator;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool enableSuggestions;
  final bool autocorrect;
  final Widget? suffixIcon;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<LoginTextField> createState() => _LoginTextFieldState();
}

class _LoginTextFieldState extends State<LoginTextField> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fillColor = switch ((theme.brightness, _isHovered)) {
      (Brightness.light, false) => colors.secondaryContainer,
      (Brightness.light, true) => colors.secondary,
      (Brightness.dark, false) => colors.surfaceContainer,
      (Brightness.dark, true) => colors.surfaceContainerHigh,
    };

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.text : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: TextFormField(
        key: widget.fieldKey,
        controller: widget.controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        obscureText: widget.obscureText,
        enableSuggestions: widget.enableSuggestions,
        autocorrect: widget.autocorrect,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          fillColor: fillColor,
          prefixIcon: Icon(widget.prefixIcon),
          suffixIcon: widget.suffixIcon,
        ),
        validator: widget.validator,
        onFieldSubmitted: widget.onFieldSubmitted,
      ),
    );
  }
}
