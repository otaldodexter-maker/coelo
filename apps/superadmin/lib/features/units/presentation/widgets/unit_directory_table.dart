import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/unit_directory.dart';
import '../unit_directory_table_view.dart';
import 'unit_status_presentation.dart';

final class UnitDirectoryTable extends StatelessWidget {
  const UnitDirectoryTable({
    required this.items,
    required this.createAction,
    required this.onEdit,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    required this.view,
    super.key,
  });

  final List<UnitDirectoryItem> items;
  final Widget createAction;
  final ValueChanged<UnitDirectoryItem> onEdit;
  final UnitDirectorySortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<UnitDirectorySortColumn> onSort;
  final UnitDirectoryTableView view;

  @override
  Widget build(BuildContext context) {
    final columns = _columnsFor(view);
    final activeSortColumn = columns.where((column) => column.sortColumn == sortColumn).firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          SizedBox(width: constraints.maxWidth, child: createAction),
          const SizedBox(height: CoeloSpacing.space4),
          SizedBox(
            key: const Key('unit-directory-table-viewport'),
            width: constraints.maxWidth,
            child: KeyedSubtree(
              key: Key('unit-directory-table-${view.name}'),
              child: view == UnitDirectoryTableView.grouped
                  ? CoeloAdminResizableTable<UnitDirectoryItem>(
                      key: const Key('unit-directory-table'),
                      items: items,
                      rowKey: (item) => 'unit-table-row-${item.id}',
                      pinnedColumn: _column(_UnitColumn.unit),
                      columns: columns.skip(1).map(_column).toList(growable: false),
                      headerHeight: 56,
                      rowHeight: 64,
                      onRowPressed: onEdit,
                      sortColumnId: activeSortColumn?.id ?? _UnitColumn.unit.id,
                      sortAscending: sortAscending,
                      onSort: (id) {
                        final column = _UnitColumn.values.firstWhere((value) => value.id == id);
                        if (column.sortColumn != null) onSort(column.sortColumn!);
                      },
                    )
                  : _detailTable(view),
            ),
          ),
        ],
      ),
    );
  }

  CoeloAdminTableColumn<UnitDirectoryItem> _column(_UnitColumn column) {
    return CoeloAdminTableColumn<UnitDirectoryItem>(
      id: column.id,
      label: column.label,
      initialWidth: column.initialWidth,
      minWidth: column.minimumWidth,
      maxWidth: 600,
      sortable: column.sortColumn != null,
      cellBuilder: (context, item) => switch (column) {
        _UnitColumn.unit => _unitCell(context, item),
        _UnitColumn.institution => _text(item.institutionName),
        _UnitColumn.type => _text(item.typeName),
        _UnitColumn.groups => _text('${item.groupsCount}'),
        _UnitColumn.activities => _text('${item.activitiesCount}'),
        _UnitColumn.administrators => _text('${_unitMetrics(item).administrators}'),
        _UnitColumn.team => _text('${_unitMetrics(item).team}'),
        _UnitColumn.guardians => _text('${_unitMetrics(item).guardians}'),
        _UnitColumn.children => _text('${_unitMetrics(item).children}'),
        _UnitColumn.plan => _text(item.effectivePlan.label),
        _UnitColumn.status => Align(
          alignment: Alignment.centerLeft,
          child: UnitStatusChip(status: item.status),
        ),
        _UnitColumn.email => _copyable(item, 'email', 'E-mail', item.contactEmail),
        _UnitColumn.phone => _copyable(item, 'phone', 'Telefone', item.contactPhone),
        _UnitColumn.mobile => _copyable(item, 'mobile', 'Celular', item.contactMobilePhone),
        _UnitColumn.street => _text(item.street),
        _UnitColumn.number => _text(item.addressNumber),
        _UnitColumn.complement => _text(item.complement),
        _UnitColumn.district => _text(item.district),
        _UnitColumn.postalCode => _text(item.postalCode),
        _UnitColumn.city => _text(item.city),
        _UnitColumn.state => _text(item.state),
      },
    );
  }

  Widget _detailTable(UnitDirectoryTableView level) {
    final rows = _unitHierarchyRows(items, level);
    final columns = level == UnitDirectoryTableView.groups
        ? const [
            _UnitDetailColumn.unit,
            _UnitDetailColumn.group,
            _UnitDetailColumn.administrators,
            _UnitDetailColumn.team,
            _UnitDetailColumn.guardians,
            _UnitDetailColumn.children,
            _UnitDetailColumn.status,
          ]
        : const [
            _UnitDetailColumn.unit,
            _UnitDetailColumn.group,
            _UnitDetailColumn.activity,
            _UnitDetailColumn.team,
            _UnitDetailColumn.children,
            _UnitDetailColumn.status,
          ];
    return CoeloAdminResizableTable<_UnitHierarchyRow>(
      key: const Key('unit-directory-table'),
      items: rows,
      rowKey: (row) => 'unit-detail-row-${level.name}-${row.id}',
      pinnedColumn: _detailColumn(_UnitDetailColumn.institution),
      columns: columns.map(_detailColumn).toList(growable: false),
      headerHeight: 56,
      rowHeight: 64,
      onRowPressed: (row) => onEdit(row.unit),
      sortColumnId: _UnitDetailColumn.institution.id,
      sortAscending: true,
      onSort: (_) {},
    );
  }

  CoeloAdminTableColumn<_UnitHierarchyRow> _detailColumn(_UnitDetailColumn column) =>
      CoeloAdminTableColumn<_UnitHierarchyRow>(
        id: column.id,
        label: column.label,
        initialWidth: column.initialWidth,
        minWidth: column.minimumWidth,
        maxWidth: 600,
        sortable: false,
        cellBuilder: (context, row) => switch (column) {
          _UnitDetailColumn.institution => _text(row.unit.institutionName),
          _UnitDetailColumn.unit => _unitCell(context, row.unit),
          _UnitDetailColumn.group => _text(row.groupName),
          _UnitDetailColumn.activity => _text(row.activityName ?? '—'),
          _UnitDetailColumn.administrators => _text('${row.metrics.administrators}'),
          _UnitDetailColumn.team => _text('${row.metrics.team}'),
          _UnitDetailColumn.guardians => _text('${row.metrics.guardians}'),
          _UnitDetailColumn.children => _text('${row.metrics.children}'),
          _UnitDetailColumn.status => Align(
            alignment: Alignment.centerLeft,
            child: UnitStatusChip(status: row.unit.status),
          ),
        },
      );

  Widget _unitCell(BuildContext context, UnitDirectoryItem item) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: colors.secondaryContainer, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            item.initials,
            style: DefaultTextStyle.of(context).style.copyWith(color: colors.onSecondaryContainer),
          ),
        ),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _text(String value) => Align(
    alignment: Alignment.centerLeft,
    child: Text(value.isEmpty ? '—' : value, maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  Widget _copyable(UnitDirectoryItem item, String kind, String label, String value) {
    return Row(
      children: [
        Expanded(child: _text(value)),
        if (value.isNotEmpty)
          IconButton(
            key: Key('copy-unit-$kind-${item.id}'),
            onPressed: () => Clipboard.setData(ClipboardData(text: value)),
            tooltip: 'Copiar $label',
            icon: const Icon(Icons.content_copy_rounded),
            iconSize: CoeloSize.iconSm,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              width: CoeloSpacing.space8,
              height: CoeloSpacing.space8,
            ),
          ),
      ],
    );
  }
}

List<_UnitColumn> _columnsFor(UnitDirectoryTableView view) => switch (view) {
  UnitDirectoryTableView.grouped => _UnitColumn.values,
  UnitDirectoryTableView.groups => const [
    _UnitColumn.unit,
    _UnitColumn.institution,
    _UnitColumn.groups,
    _UnitColumn.status,
  ],
  UnitDirectoryTableView.activities => const [
    _UnitColumn.unit,
    _UnitColumn.institution,
    _UnitColumn.activities,
    _UnitColumn.status,
  ],
};

enum _UnitColumn {
  unit('unit', 'Unidade', 220, 180, UnitDirectorySortColumn.name),
  institution('institution', 'Instituição', 220, 180, UnitDirectorySortColumn.institutionName),
  type('type', 'Tipo', 190, 140, UnitDirectorySortColumn.typeName),
  groups('groups', 'Turmas', 100, 88, UnitDirectorySortColumn.groupsCount),
  activities('activities', 'Atividades', 110, 96, UnitDirectorySortColumn.activitiesCount),
  administrators('administrators', 'Administradores', 160, 140, null),
  team('team', 'Equipe institucional', 180, 150, null),
  guardians('guardians', 'Responsáveis', 140, 120, null),
  children('children', 'Crianças', 120, 100, null),
  plan('plan', 'Plano', 150, 120, UnitDirectorySortColumn.planName),
  status('status', 'Status', 150, 120, UnitDirectorySortColumn.status),
  email('email', 'E-mail', 240, 180, UnitDirectorySortColumn.contactEmail),
  phone('phone', 'Telefone', 200, 160, UnitDirectorySortColumn.contactPhone),
  mobile('mobile', 'Celular', 200, 160, UnitDirectorySortColumn.contactMobilePhone),
  street('street', 'Logradouro', 220, 160, UnitDirectorySortColumn.street),
  number('number', 'Número', 110, 88, UnitDirectorySortColumn.addressNumber),
  complement('complement', 'Complemento', 170, 130, UnitDirectorySortColumn.complement),
  district('district', 'Bairro', 150, 120, UnitDirectorySortColumn.district),
  postalCode('postal-code', 'CEP', 130, 110, UnitDirectorySortColumn.postalCode),
  city('city', 'Município', 170, 130, UnitDirectorySortColumn.city),
  state('state', 'UF', 80, 64, UnitDirectorySortColumn.state);

  const _UnitColumn(this.id, this.label, this.initialWidth, this.minimumWidth, this.sortColumn);

  final String id;
  final String label;
  final double initialWidth;
  final double minimumWidth;
  final UnitDirectorySortColumn? sortColumn;
}

enum _UnitDetailColumn {
  institution('institution', 'Instituição', 220, 180),
  unit('unit-name', 'Unidade', 220, 180),
  group('group-name', 'Turma', 220, 180),
  activity('activity-name', 'Atividade', 220, 180),
  administrators('administrators', 'Administradores', 160, 140),
  team('team', 'Equipe institucional', 180, 150),
  guardians('guardians', 'Responsáveis', 140, 120),
  children('children', 'Crianças', 120, 100),
  status('status', 'Status', 150, 120);

  const _UnitDetailColumn(this.id, this.label, this.initialWidth, this.minimumWidth);

  final String id;
  final String label;
  final double initialWidth;
  final double minimumWidth;
}

typedef _UnitMetrics = ({int administrators, int team, int guardians, int children});

final class _UnitHierarchyRow {
  const _UnitHierarchyRow({
    required this.id,
    required this.unit,
    required this.groupName,
    required this.metrics,
    this.activityName,
  });

  final String id;
  final UnitDirectoryItem unit;
  final String groupName;
  final String? activityName;
  final _UnitMetrics metrics;
}

List<_UnitHierarchyRow> _unitHierarchyRows(
  List<UnitDirectoryItem> source,
  UnitDirectoryTableView level,
) {
  final units = [...source]
    ..sort((a, b) {
      final institution = a.institutionName.compareTo(b.institutionName);
      return institution != 0 ? institution : a.name.compareTo(b.name);
    });
  final rows = <_UnitHierarchyRow>[];
  for (final unit in units) {
    final groupCount = unit.groupsCount.clamp(1, 8);
    if (level == UnitDirectoryTableView.groups) {
      for (var group = 0; group < groupCount; group++) {
        final id = '${unit.id}-g${group + 1}';
        rows.add(
          _UnitHierarchyRow(
            id: id,
            unit: unit,
            groupName: 'Turma ${(group + 1).toString().padLeft(2, '0')}',
            metrics: _unitHierarchyMetrics(id),
          ),
        );
      }
      continue;
    }
    final activityCount = unit.activitiesCount.clamp(1, 12);
    for (var activity = 0; activity < activityCount; activity++) {
      final group = activity % groupCount;
      final id = '${unit.id}-g${group + 1}-a${activity + 1}';
      rows.add(
        _UnitHierarchyRow(
          id: id,
          unit: unit,
          groupName: 'Turma ${(group + 1).toString().padLeft(2, '0')}',
          activityName: 'Atividade ${(activity + 1).toString().padLeft(2, '0')}',
          metrics: _unitHierarchyMetrics(id),
        ),
      );
    }
  }
  rows.sort((a, b) {
    final valuesA = [a.unit.institutionName, a.unit.name, a.groupName, a.activityName ?? ''];
    final valuesB = [b.unit.institutionName, b.unit.name, b.groupName, b.activityName ?? ''];
    for (var index = 0; index < valuesA.length; index++) {
      final comparison = valuesA[index].compareTo(valuesB[index]);
      if (comparison != 0) return comparison;
    }
    return 0;
  });
  return rows;
}

_UnitMetrics _unitMetrics(UnitDirectoryItem item) => _unitHierarchyMetrics(item.id);

_UnitMetrics _unitHierarchyMetrics(String id) {
  final seed = id.codeUnits.fold<int>(0, (sum, value) => sum + value);
  return (
    administrators: 1 + seed % 2,
    team: 2 + seed % 6,
    guardians: 5 + seed % 11,
    children: 7 + seed % 14,
  );
}
