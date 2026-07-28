import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class CoeloAdminSingleSelectField<T> extends StatelessWidget {
  const CoeloAdminSingleSelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    this.prefixIcon = Icons.tune_rounded,
    super.key,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T value) optionLabel;
  final ValueChanged<T> onChanged;
  final IconData prefixIcon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        crossAxisUnconstrained: false,
        alignmentOffset: const Offset(0, CoeloSpacing.space1),
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surface),
          elevation: const WidgetStatePropertyAll(CoeloElevation.level3),
          minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
          maximumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, double.infinity)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              side: BorderSide(color: colors.outlineVariant),
            ),
          ),
        ),
        menuChildren: [
          for (final option in options)
            MenuItemButton(
              onPressed: () => onChanged(option),
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size.fromHeight(CoeloSize.touchMin)),
                shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      option == value ||
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? colors.primary
                      : colors.onSurface,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      option == value ||
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? colors.primaryContainer
                      : colors.surface,
                ),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
              child: Text(optionLabel(option)),
            ),
        ],
        builder: (context, menu, child) => InkWell(
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          onTap: () => menu.isOpen ? menu.close() : menu.open(),
          child: InputDecorator(
            isFocused: menu.isOpen,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(prefixIcon),
              suffixIcon: Icon(
                menu.isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              ),
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            child: Text(optionLabel(value)),
          ),
        ),
      ),
    );
  }
}
