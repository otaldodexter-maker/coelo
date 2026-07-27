import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class CoeloSearchField extends StatelessWidget {
  const CoeloSearchField({
    required this.controller,
    required this.onChanged,
    required this.semanticLabel,
    this.hintText,
    this.focusNode,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String semanticLabel;
  final String? hintText;
  final FocusNode? focusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(CoeloRadius.full),
      borderSide: BorderSide(color: colors.outline),
    );

    return Semantics(
      label: semanticLabel,
      textField: true,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(borderSide: BorderSide(color: colors.primary, width: 2)),
        ),
      ),
    );
  }
}
