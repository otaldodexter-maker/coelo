import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../domain/unit_directory.dart';

(Color, Color) unitStatusColors(BuildContext context, UnitStatus status) {
  final theme = Theme.of(context);
  final statusColors =
      theme.extension<CoeloStatusColors>() ??
      (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
  return switch (status) {
    UnitStatus.active => (Colors.transparent, statusColors.onSuccessContainer),
    UnitStatus.suspended => (Colors.transparent, statusColors.onErrorContainer),
    UnitStatus.draft => (Colors.transparent, statusColors.onWarningContainer),
    UnitStatus.inactive ||
    UnitStatus.archived => (Colors.transparent, theme.colorScheme.onSurfaceVariant),
  };
}

IconData unitStatusIcon(UnitStatus status) => switch (status) {
  UnitStatus.active => Icons.check_circle_outline_rounded,
  UnitStatus.suspended => Icons.pause_circle_outline_rounded,
  UnitStatus.draft => Icons.edit_note_rounded,
  UnitStatus.inactive => Icons.remove_circle_outline_rounded,
  UnitStatus.archived => Icons.archive_outlined,
};

final class UnitStatusChip extends StatelessWidget {
  const UnitStatusChip({required this.status, super.key});

  final UnitStatus status;

  @override
  Widget build(BuildContext context) {
    return _LightUnitStatus(status: status, surfaceKey: Key('unit-status-chip-${status.name}'));
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
  bool _hovered = false;
  bool _focused = false;
  bool _expandedByTap = false;

  bool get _expanded => _hovered || _focused || _expandedByTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = unitStatusColors(context, widget.status);
    final label = widget.status.label;
    final expandedWidth = math.max(72, 48 + label.length * 6.5);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: Semantics(
          button: true,
          label: 'Status: $label',
          child: GestureDetector(
            onTap: () => setState(() => _expandedByTap = !_expandedByTap),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _expanded ? 1 : 0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : CoeloMotion.standard,
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => Container(
                key: Key('unit-status-${widget.itemId}'),
                width: 24 + (expandedWidth - 24) * progress,
                height: CoeloSpacing.space6,
                padding: EdgeInsets.symmetric(horizontal: CoeloSpacing.space1 * progress),
                decoration: BoxDecoration(
                  color: colors.$1,
                  borderRadius: BorderRadius.circular(CoeloRadius.full),
                  border: Border.all(
                    color: colors.$2.withValues(alpha: _focused ? .48 : .28),
                    width: _focused ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(unitStatusIcon(widget.status), size: CoeloSize.iconSm, color: colors.$2),
                    if (progress > 0) ...[
                      SizedBox(width: CoeloSpacing.space1 * progress),
                      Flexible(
                        child: Opacity(
                          opacity: progress,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: theme.textTheme.labelSmall?.copyWith(color: colors.$2),
                          ),
                        ),
                      ),
                    ],
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

final class _LightUnitStatus extends StatelessWidget {
  const _LightUnitStatus({required this.status, required this.surfaceKey});

  final UnitStatus status;
  final Key surfaceKey;

  @override
  Widget build(BuildContext context) {
    final colors = unitStatusColors(context, status);
    return Semantics(
      label: 'Status: ${status.label}',
      child: Container(
        key: surfaceKey,
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space1,
          vertical: CoeloSpacing.spaceHalf,
        ),
        decoration: BoxDecoration(
          color: colors.$1,
          borderRadius: BorderRadius.circular(CoeloRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(unitStatusIcon(status), size: CoeloSize.iconSm, color: colors.$2),
            const SizedBox(width: CoeloSpacing.space1),
            Text(
              status.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.$2),
            ),
          ],
        ),
      ),
    );
  }
}
