import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class CoeloFormTextField extends StatefulWidget {
  const CoeloFormTextField({
    required this.controller,
    required this.labelText,
    required this.prefixIcon,
    this.fieldKey,
    this.focusNode,
    this.hintText,
    this.prefixText,
    this.suffixIcon,
    this.errorText,
    this.validator,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.onChanged,
    this.onFieldSubmitted,
    super.key,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String labelText;
  final String? hintText;
  final String? prefixText;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool enableSuggestions;
  final bool autocorrect;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<CoeloFormTextField> createState() => _CoeloFormTextFieldState();
}

final class _CoeloFormTextFieldState extends State<CoeloFormTextField> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fillColor = switch ((theme.brightness, _hovered)) {
      (Brightness.light, false) => colors.surfaceContainerLowest,
      (Brightness.light, true) => colors.surfaceContainerLow,
      (Brightness.dark, false) => colors.surfaceContainer,
      (Brightness.dark, true) => colors.surfaceContainerHigh,
    };
    Widget prefixIcon = Icon(widget.prefixIcon);
    if (widget.maxLines > 1) {
      final inputStyle = theme.useMaterial3
          ? theme.textTheme.bodyLarge!
          : theme.textTheme.titleMedium!;
      final linePainter = TextPainter(
        text: TextSpan(text: 'M', style: inputStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      prefixIcon = SizedBox(
        width: CoeloSize.touchMin,
        height: linePainter.height * widget.maxLines,
        child: Align(alignment: Alignment.topCenter, child: prefixIcon),
      );
      linePainter.dispose();
    }
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.text : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
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
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        textAlignVertical: widget.maxLines > 1 ? TextAlignVertical.top : null,
        inputFormatters: widget.inputFormatters,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          prefixText: widget.prefixText,
          prefixIcon: prefixIcon,
          suffixIcon: widget.suffixIcon,
          errorText: widget.errorText,
          fillColor: fillColor,
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
        validator: widget.validator,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onFieldSubmitted,
      ),
    );
  }
}
