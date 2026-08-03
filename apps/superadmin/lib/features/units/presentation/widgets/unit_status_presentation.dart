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

final class ExpandableUnitStatusIndicator extends StatelessWidget {
  const ExpandableUnitStatusIndicator({required this.itemId, required this.status, super.key});

  final String itemId;
  final UnitStatus status;

  @override
  Widget build(BuildContext context) {
    return _LightUnitStatus(status: status, surfaceKey: Key('unit-status-$itemId'));
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
