import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../domain/staff_access.dart';

(Color, Color) staffAccessStateColors(BuildContext context, StaffAccessState state) {
  final theme = Theme.of(context);
  final status = context.coeloStatusColors;
  return switch (state) {
    StaffAccessState.free => (status.successContainer, status.onSuccessContainer),
    StaffAccessState.schedule ||
    StaffAccessState.validity => (status.warningContainer, status.onWarningContainer),
    StaffAccessState.leave => (theme.colorScheme.surfaceContainer, theme.colorScheme.onSurfaceVariant),
    StaffAccessState.blockedNow => (status.errorContainer, status.onErrorContainer),
  };
}

IconData staffAccessStateIcon(StaffAccessState state) => switch (state) {
  StaffAccessState.free => Icons.lock_open_rounded,
  StaffAccessState.schedule => Icons.schedule_rounded,
  StaffAccessState.validity => Icons.event_available_outlined,
  StaffAccessState.leave => Icons.beach_access_outlined,
  StaffAccessState.blockedNow => Icons.lock_outline_rounded,
};

/// Chip compacto de estado (tabela e formulário).
final class StaffAccessStateChip extends StatelessWidget {
  const StaffAccessStateChip({required this.state, super.key});
  final StaffAccessState state;

  @override
  Widget build(BuildContext context) {
    final colors = staffAccessStateColors(context, state);
    return Semantics(
      label: 'Estado: ${state.label}',
      child: Container(
        key: Key('staff-access-state-chip-${state.name}'),
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
            Icon(staffAccessStateIcon(state), size: CoeloSize.iconSm, color: colors.$2),
            const SizedBox(width: CoeloSpacing.space1),
            Flexible(
              child: Text(
                state.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.$2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resumo curto da regra para cards, tabela e popup.
String staffAccessRuleSummary(StaffAccessRule? rule) {
  if (rule == null) return 'Sem restrição';
  final parts = <String>[];
  if (rule.windows.isNotEmpty) {
    final days = rule.windows.map((w) => w.weekday).toSet().toList()..sort();
    parts.add(
      '${days.map((d) => StaffAccessWindow.weekdayShortLabels[d]).join(', ')} · '
      '${rule.windows.length} ${rule.windows.length == 1 ? 'janela' : 'janelas'}',
    );
  }
  if (rule.validFrom != null || rule.validUntil != null) {
    parts.add(
      'Vigência ${rule.validFrom == null ? '…' : staffAccessDateLabel(rule.validFrom!)}'
      ' – ${rule.validUntil == null ? '…' : staffAccessDateLabel(rule.validUntil!)}',
    );
  }
  if (rule.surfaces.length < StaffAccessSurface.values.length) {
    parts.add(rule.surfaces.map((s) => s.label).join(', '));
  }
  return parts.isEmpty ? 'Sem restrição' : parts.join(' · ');
}

/// Card do vínculo (anatomia de Instituições: `CoeloAdminInteractiveCard`).
final class StaffAccessCard extends StatelessWidget {
  const StaffAccessCard({required this.item, required this.onPressed, super.key});

  final StaffAccessItem item;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (stateBackground, stateForeground) = staffAccessStateColors(context, item.state);
    return CoeloAdminInteractiveCard(
      key: Key('staff-access-card-${item.membershipId}'),
      surfaceKey: Key('staff-access-card-surface-${item.membershipId}'),
      minHeight: 216,
      semanticLabel: '${item.personName}. ${item.roleName}. ${item.scopeLabel}. Estado: ${item.state.label}',
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space6,
          vertical: CoeloSpacing.space4,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: colors.secondaryContainer, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    item.initials,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSecondaryContainer),
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.personName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        item.roleName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                CoeloAdminExpandableStatusIndicator(
                  label: item.state.label,
                  backgroundColor: stateBackground,
                  foregroundColor: stateForeground,
                  semanticLabel: 'Estado: ${item.state.label}',
                  surfaceKey: Key('staff-access-state-${item.membershipId}'),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Row(
              children: [
                Text('Vínculo', style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(width: CoeloSpacing.space2),
                Expanded(
                  child: Text(
                    item.scopeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space3),
            const Divider(height: 1),
            const SizedBox(height: CoeloSpacing.space3),
            _Detail(
              icon: Icons.schedule_rounded,
              label: 'Regra',
              value: staffAccessRuleSummary(item.rule),
            ),
            const SizedBox(height: CoeloSpacing.space3),
            _Detail(
              icon: Icons.beach_access_outlined,
              label: 'Afastamentos',
              value: item.currentLeave != null
                  ? 'Afastado até ${staffAccessDateLabel(item.currentLeave!.endsOn)}'
                  : item.leavesCount == 0
                  ? 'Nenhum'
                  : '${item.leavesCount} registrado${item.leavesCount == 1 ? '' : 's'}',
            ),
          ],
        ),
      ),
    );
  }
}

final class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: CoeloSize.iconSm, color: colors.onSurfaceVariant),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
              Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

enum StaffAccessTableView { grouped }

enum _StaffAccessColumn {
  person('person', 'Funcionário', 260, 180),
  role('role', 'Papel', 170, 120),
  institution('institution', 'Instituição', 200, 140),
  unit('unit', 'Unidade / turma', 220, 140),
  state('state', 'Estado', 160, 120),
  rule('rule', 'Regra', 320, 160),
  leaves('leaves', 'Afastamentos', 160, 120);

  const _StaffAccessColumn(this.id, this.label, this.initialWidth, this.minimumWidth);
  final String id;
  final String label;
  final double initialWidth;
  final double minimumWidth;
}

/// Linhas de domínio sobre a tabela compartilhada.
final class StaffAccessTableRows extends StatelessWidget {
  const StaffAccessTableRows({required this.items, this.onEdit, super.key});

  final List<StaffAccessItem> items;
  final ValueChanged<StaffAccessItem>? onEdit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      key: const Key('staff-access-table-viewport'),
      width: constraints.maxWidth,
      child: CoeloAdminResizableTable<StaffAccessItem>(
        key: const Key('staff-access-table'),
        items: items,
        rowKey: (item) => 'staff-access-row-${item.membershipId}',
        pinnedColumn: _column(_StaffAccessColumn.person),
        columns: _StaffAccessColumn.values.skip(1).map(_column).toList(growable: false),
        headerHeight: 56,
        rowHeight: 64,
        onRowPressed: onEdit,
        sortColumnId: _StaffAccessColumn.person.id,
        sortAscending: true,
        onSort: (_) {},
      ),
    ),
  );

  CoeloAdminTableColumn<StaffAccessItem> _column(_StaffAccessColumn column) =>
      CoeloAdminTableColumn<StaffAccessItem>(
        id: column.id,
        label: column.label,
        initialWidth: column.initialWidth,
        minWidth: column.minimumWidth,
        maxWidth: 600,
        sortable: false,
        cellBuilder: (context, item) => switch (column) {
          _StaffAccessColumn.person => _text(item.personName, bold: true),
          _StaffAccessColumn.role => _text(item.roleName),
          _StaffAccessColumn.institution => _text(item.institutionName),
          _StaffAccessColumn.unit => _text(
            [item.unitName, item.groupName].whereType<String>().join(' · '),
          ),
          _StaffAccessColumn.state => Align(
            alignment: Alignment.centerLeft,
            child: StaffAccessStateChip(state: item.state),
          ),
          _StaffAccessColumn.rule => _text(staffAccessRuleSummary(item.rule)),
          _StaffAccessColumn.leaves => _text(
            item.currentLeave != null
                ? 'Até ${staffAccessDateLabel(item.currentLeave!.endsOn)}'
                : '${item.leavesCount}',
          ),
        },
      );

  Widget _text(String value, {bool bold = false}) => Builder(
    builder: (context) => Text(
      value.isEmpty ? '—' : value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: bold ? FontWeight.w600 : null,
      ),
    ),
  );
}

enum _StaffLeaveColumn {
  person('person', 'Funcionário', 260, 180),
  scope('scope', 'Vínculo', 260, 160),
  period('period', 'Período', 220, 160),
  popup('popup', 'Popup', 120, 100),
  note('note', 'Motivo interno', 300, 160);

  const _StaffLeaveColumn(this.id, this.label, this.initialWidth, this.minimumWidth);
  final String id;
  final String label;
  final double initialWidth;
  final double minimumWidth;
}

final class StaffLeaveTableRows extends StatelessWidget {
  const StaffLeaveTableRows({required this.items, this.onEdit, super.key});

  final List<StaffLeave> items;
  final ValueChanged<StaffLeave>? onEdit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      key: const Key('staff-leave-table-viewport'),
      width: constraints.maxWidth,
      child: CoeloAdminResizableTable<StaffLeave>(
        key: const Key('staff-leave-table'),
        items: items,
        rowKey: (item) => 'staff-leave-row-${item.id}',
        pinnedColumn: _column(_StaffLeaveColumn.person),
        columns: _StaffLeaveColumn.values.skip(1).map(_column).toList(growable: false),
        headerHeight: 56,
        rowHeight: 64,
        onRowPressed: onEdit,
        sortColumnId: _StaffLeaveColumn.period.id,
        sortAscending: false,
        onSort: (_) {},
      ),
    ),
  );

  CoeloAdminTableColumn<StaffLeave> _column(_StaffLeaveColumn column) =>
      CoeloAdminTableColumn<StaffLeave>(
        id: column.id,
        label: column.label,
        initialWidth: column.initialWidth,
        minWidth: column.minimumWidth,
        maxWidth: 600,
        sortable: false,
        cellBuilder: (context, item) {
          final text = switch (column) {
            _StaffLeaveColumn.person => item.membership?.personName ?? '',
            _StaffLeaveColumn.scope => item.membership?.scopeLabel ?? '',
            _StaffLeaveColumn.period => staffLeavePeriodLabel(item),
            _StaffLeaveColumn.popup => item.popupEnabled ? 'Ligado' : 'Desligado',
            _StaffLeaveColumn.note => item.internalNote ?? '',
          };
          return Text(
            text.isEmpty ? '—' : text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: column == _StaffLeaveColumn.person ? FontWeight.w600 : null,
            ),
          );
        },
      );
}

String staffLeavePeriodLabel(StaffLeave leave) =>
    '${staffAccessDateLabel(leave.startsOn)} – ${staffAccessDateLabel(leave.endsOn)}';

/// Card de afastamento.
final class StaffLeaveCard extends StatelessWidget {
  const StaffLeaveCard({required this.item, required this.onPressed, super.key});

  final StaffLeave item;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final membership = item.membership;
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final current = !item.startsOn.isAfter(day) && !item.endsOn.isBefore(day);
    final upcoming = item.startsOn.isAfter(day);
    final status = current ? 'Em curso' : upcoming ? 'Futuro' : 'Encerrado';
    final statusColors = context.coeloStatusColors;
    final (bg, fg) = current
        ? (statusColors.errorContainer, statusColors.onErrorContainer)
        : upcoming
        ? (statusColors.warningContainer, statusColors.onWarningContainer)
        : (colors.surfaceContainer, colors.onSurfaceVariant);
    return CoeloAdminInteractiveCard(
      key: Key('staff-leave-card-${item.id}'),
      surfaceKey: Key('staff-leave-card-surface-${item.id}'),
      minHeight: 216,
      semanticLabel:
          '${membership?.personName ?? 'Afastamento'}. ${staffLeavePeriodLabel(item)}. $status',
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space6,
          vertical: CoeloSpacing.space4,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: colors.secondaryContainer, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(Icons.beach_access_outlined, color: colors.onSecondaryContainer),
                ),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        membership?.personName ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        membership?.scopeLabel ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                CoeloAdminExpandableStatusIndicator(
                  label: status,
                  backgroundColor: bg,
                  foregroundColor: fg,
                  semanticLabel: 'Situação: $status',
                  surfaceKey: Key('staff-leave-status-${item.id}'),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space3),
            const Divider(height: 1),
            const SizedBox(height: CoeloSpacing.space3),
            _Detail(icon: Icons.date_range_outlined, label: 'Período', value: staffLeavePeriodLabel(item)),
            const SizedBox(height: CoeloSpacing.space3),
            _Detail(
              icon: Icons.notifications_active_outlined,
              label: 'Popup ao funcionário',
              value: item.popupEnabled ? 'Ligado' : 'Desligado',
            ),
            if (item.internalNote != null && item.internalNote!.isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space3),
              _Detail(icon: Icons.notes_outlined, label: 'Motivo interno', value: item.internalNote!),
            ],
          ],
        ),
      ),
    );
  }
}
