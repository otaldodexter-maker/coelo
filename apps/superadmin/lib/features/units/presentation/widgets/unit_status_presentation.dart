import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../domain/unit_directory.dart';

(Color, Color) unitStatusColors(BuildContext context, UnitStatus status) {
  final theme = Theme.of(context);
  final statusColors =
      theme.extension<CoeloStatusColors>() ??
      (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
  return switch (status) {
    UnitStatus.active => (statusColors.successContainer, statusColors.onSuccessContainer),
    UnitStatus.suspended => (statusColors.errorContainer, statusColors.onErrorContainer),
    UnitStatus.draft => (statusColors.warningContainer, statusColors.onWarningContainer),
    UnitStatus.inactive ||
    UnitStatus.archived => (theme.colorScheme.surfaceContainer, theme.colorScheme.onSurfaceVariant),
  };
}

final class UnitStatusChip extends StatelessWidget {
  const UnitStatusChip({required this.status, super.key});

  final UnitStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = unitStatusColors(context, status);
    return CoeloStatusChip(
      label: status.label,
      backgroundColor: colors.$1,
      foregroundColor: colors.$2,
    );
  }
}

final class ExpandableUnitStatusIndicator extends StatefulWidget {
  const ExpandableUnitStatusIndicator({required this.itemId, required this.status, super.key});

  final String itemId;
  final UnitStatus status;

  @override
  State<ExpandableUnitStatusIndicator> createState() => _ExpandableUnitStatusIndicatorState();
}

final class _ExpandableUnitStatusIndicatorState extends State<ExpandableUnitStatusIndicator> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final colors = unitStatusColors(context, widget.status);
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : CoeloMotion.short;
    return Semantics(
      label: 'Status: ${widget.status.label}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _highlighted = true),
        onExit: (_) => setState(() => _highlighted = false),
        child: FocusableActionDetector(
          onShowFocusHighlight: (value) => setState(() => _highlighted = value),
          child: AnimatedContainer(
            key: Key('unit-status-${widget.itemId}'),
            duration: duration,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.symmetric(horizontal: _highlighted ? CoeloSpacing.space2 : 0),
            decoration: BoxDecoration(
              color: colors.$1,
              borderRadius: BorderRadius.circular(CoeloRadius.full),
              border: Border.all(color: colors.$2.withValues(alpha: .3)),
            ),
            alignment: Alignment.center,
            child: _highlighted
                ? Text(
                    widget.status.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.$2),
                  )
                : SizedBox.square(
                    dimension: CoeloSpacing.space2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: colors.$2, shape: BoxShape.circle),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
