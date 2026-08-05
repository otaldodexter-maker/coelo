import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Canonical boolean field for administrative Coelo forms.
final class CoeloAdminToggleField extends StatelessWidget {
  const CoeloAdminToggleField({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onChanged != null;

    return Semantics(
      container: true,
      label: label,
      toggled: value,
      enabled: enabled,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: enabled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space1),
                SwitchTheme(
                  data: theme.switchTheme.copyWith(
                    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                  ),
                  child: Switch(
                    value: value,
                    onChanged: onChanged,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
