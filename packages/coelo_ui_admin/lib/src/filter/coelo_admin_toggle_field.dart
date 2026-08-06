import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Canonical boolean field for administrative Coelo forms.
final class CoeloAdminToggleField extends StatefulWidget {
  const CoeloAdminToggleField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    super.key,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<CoeloAdminToggleField> createState() => _CoeloAdminToggleFieldState();
}

final class _CoeloAdminToggleFieldState extends State<CoeloAdminToggleField> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.onChanged != null;
    final highlighted = enabled && (_hovered || _focused);

    return Semantics(
      container: true,
      label: widget.label,
      toggled: widget.value,
      enabled: enabled,
      onTap: enabled ? () => widget.onChanged!(!widget.value) : null,
      child: ExcludeSemantics(
        child: MouseRegion(
          onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
          onExit: enabled ? (_) => setState(() => _hovered = false) : null,
          child: FocusableActionDetector(
            enabled: enabled,
            onShowFocusHighlight: (value) => setState(() => _focused = value),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? () => widget.onChanged!(!widget.value) : null,
              child: AnimatedContainer(
                duration: CoeloMotion.fast,
                constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
                padding: const EdgeInsets.symmetric(
                  horizontal: CoeloSpacing.space3,
                  vertical: CoeloSpacing.space2,
                ),
                decoration: BoxDecoration(
                  color: highlighted
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(CoeloRadius.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: enabled
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                            ),
                          ),
                          if (widget.description case final description?) ...[
                            const SizedBox(height: CoeloSpacing.space1),
                            Text(
                              description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: enabled
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: CoeloSpacing.space2),
                    SwitchTheme(
                      data: theme.switchTheme.copyWith(
                        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                      ),
                      child: Switch(
                        value: widget.value,
                        onChanged: widget.onChanged,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
