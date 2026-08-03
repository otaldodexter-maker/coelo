import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/institution_directory_item.dart';
import '../../domain/institution_directory_query.dart';
import '../institution_directory_table_view.dart';
import 'institution_status_presentation.dart';

class InstitutionDirectoryTable extends StatelessWidget {
  const InstitutionDirectoryTable({
    required this.items,
    required this.view,
    required this.createAction,
    required this.onEdit,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    super.key,
  });

  final List<InstitutionDirectoryItem> items;
  final InstitutionDirectoryTableView view;
  final Widget createAction;
  final ValueChanged<InstitutionDirectoryItem> onEdit;
  final InstitutionDirectorySortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<InstitutionDirectorySortColumn> onSort;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            SizedBox(width: constraints.maxWidth, child: createAction),
            const SizedBox(height: CoeloSpacing.space4),
            KeyedSubtree(
              key: Key('institution-directory-table-${view.name}'),
              child: SizedBox(
                key: const Key('institution-directory-table-viewport'),
                width: constraints.maxWidth,
                child: view == InstitutionDirectoryTableView.grouped
                    ? _groupedTable()
                    : _detailTable(view),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _groupedTable() => CoeloAdminResizableTable<InstitutionDirectoryItem>(
    key: const Key('institution-directory-table'),
    items: items,
    rowKey: (item) => 'institution-table-row-${item.id}',
    pinnedColumn: _column(_InstitutionColumn.institution),
    columns: _columnsFor(
      InstitutionDirectoryTableView.grouped,
    ).map(_column).toList(growable: false),
    headerHeight: 56,
    rowHeight: 64,
    onRowPressed: onEdit,
    sortColumnId: _InstitutionColumn.values
        .firstWhere((column) => column.sortColumn == sortColumn)
        .id,
    sortAscending: sortAscending,
    onSort: (id) =>
        onSort(_InstitutionColumn.values.firstWhere((column) => column.id == id).sortColumn!),
  );

  Widget _detailTable(InstitutionDirectoryTableView level) {
    final rows = _institutionHierarchyRows(items, level);
    final columns = switch (level) {
      InstitutionDirectoryTableView.units => const [
        _InstitutionDetailColumn.unit,
        _InstitutionDetailColumn.administrators,
        _InstitutionDetailColumn.team,
        _InstitutionDetailColumn.guardians,
        _InstitutionDetailColumn.children,
        _InstitutionDetailColumn.status,
      ],
      InstitutionDirectoryTableView.groups => const [
        _InstitutionDetailColumn.unit,
        _InstitutionDetailColumn.group,
        _InstitutionDetailColumn.team,
        _InstitutionDetailColumn.guardians,
        _InstitutionDetailColumn.children,
      ],
      InstitutionDirectoryTableView.activities => const [
        _InstitutionDetailColumn.unit,
        _InstitutionDetailColumn.group,
        _InstitutionDetailColumn.activity,
        _InstitutionDetailColumn.team,
        _InstitutionDetailColumn.children,
        _InstitutionDetailColumn.status,
      ],
      InstitutionDirectoryTableView.grouped => const <_InstitutionDetailColumn>[],
    };
    return CoeloAdminResizableTable<_InstitutionHierarchyRow>(
      key: const Key('institution-directory-table'),
      items: rows,
      rowKey: (row) => 'institution-detail-row-${level.name}-${row.id}',
      pinnedColumn: _detailColumn(_InstitutionDetailColumn.institution),
      columns: columns.map(_detailColumn).toList(growable: false),
      headerHeight: 56,
      rowHeight: 64,
      onRowPressed: (row) => onEdit(row.institution),
      sortColumnId: _InstitutionDetailColumn.institution.id,
      sortAscending: true,
      onSort: (_) {},
    );
  }

  CoeloAdminTableColumn<_InstitutionHierarchyRow> _detailColumn(_InstitutionDetailColumn column) =>
      CoeloAdminTableColumn<_InstitutionHierarchyRow>(
        id: column.id,
        label: column.label,
        initialWidth: column.initialWidth,
        minWidth: column.minimumWidth,
        maxWidth: 600,
        sortable: false,
        cellBuilder: (context, row) => switch (column) {
          _InstitutionDetailColumn.institution => _institutionCell(context, row.institution),
          _InstitutionDetailColumn.unit => _cellText(row.unitName),
          _InstitutionDetailColumn.group => _cellText(row.groupName ?? '—'),
          _InstitutionDetailColumn.activity => _cellText(row.activityName ?? '—'),
          _InstitutionDetailColumn.administrators => _cellText('${row.metrics.administrators}'),
          _InstitutionDetailColumn.team => _cellText('${row.metrics.team}'),
          _InstitutionDetailColumn.guardians => _cellText('${row.metrics.guardians}'),
          _InstitutionDetailColumn.children => _cellText('${row.metrics.children}'),
          _InstitutionDetailColumn.status => Align(
            alignment: Alignment.centerLeft,
            child: InstitutionStatusChip(status: row.institution.status),
          ),
        },
      );

  List<_InstitutionColumn> _columnsFor(InstitutionDirectoryTableView value) => switch (value) {
    InstitutionDirectoryTableView.grouped => _InstitutionColumn.values.skip(1).toList(),
    InstitutionDirectoryTableView.units => const [
      _InstitutionColumn.units,
      _InstitutionColumn.groups,
      _InstitutionColumn.activities,
      _InstitutionColumn.team,
      _InstitutionColumn.status,
    ],
    InstitutionDirectoryTableView.groups => const [
      _InstitutionColumn.groups,
      _InstitutionColumn.activities,
      _InstitutionColumn.team,
      _InstitutionColumn.guardians,
      _InstitutionColumn.children,
    ],
    InstitutionDirectoryTableView.activities => const [
      _InstitutionColumn.activities,
      _InstitutionColumn.team,
      _InstitutionColumn.guardians,
      _InstitutionColumn.children,
      _InstitutionColumn.status,
    ],
  };

  Widget _institutionCell(BuildContext context, InstitutionDirectoryItem item) {
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
        Expanded(child: Text(item.publicName, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  CoeloAdminTableColumn<InstitutionDirectoryItem> _column(_InstitutionColumn column) {
    return CoeloAdminTableColumn<InstitutionDirectoryItem>(
      id: column.id,
      label: column.label,
      initialWidth: column.initialWidth,
      minWidth: column.minimumWidth,
      maxWidth: 600,
      sortable: column.sortColumn != null,
      cellBuilder: (context, item) => switch (column) {
        _InstitutionColumn.institution => _institutionCell(context, item),
        _InstitutionColumn.type => _cellText(item.typeName ?? 'Não informado'),
        _InstitutionColumn.units => _cellText('${item.unitsCount}'),
        _InstitutionColumn.groups => _cellText('${item.groupsCount}'),
        _InstitutionColumn.activities => _cellText('${_metricsFor(item).activities}'),
        _InstitutionColumn.legalRepresentatives => _cellText(
          '${_metricsFor(item).legalRepresentatives}',
        ),
        _InstitutionColumn.administrators => _cellText('${_metricsFor(item).administrators}'),
        _InstitutionColumn.team => _cellText('${_metricsFor(item).team}'),
        _InstitutionColumn.guardians => _cellText('${_metricsFor(item).guardians}'),
        _InstitutionColumn.children => _cellText('${_metricsFor(item).children}'),
        _InstitutionColumn.plan => _cellText(item.planName ?? 'Sem plano'),
        _InstitutionColumn.status => Align(
          alignment: Alignment.centerLeft,
          child: InstitutionStatusChip(status: item.status),
        ),
        _InstitutionColumn.email => _copyableContent(item, 'email', 'E-mail', item.contactEmail),
        _InstitutionColumn.phone => _copyableContent(item, 'phone', 'Telefone', item.contactPhone),
        _InstitutionColumn.mobile => _copyableContent(
          item,
          'mobile-phone',
          'Celular',
          item.contactMobilePhone,
        ),
        _InstitutionColumn.domain => _copyableContent(
          item,
          'domain',
          'Domínio',
          item.primaryDomain,
        ),
        _InstitutionColumn.street => _cellText(item.street ?? '—'),
        _InstitutionColumn.postalCode => _cellText(item.postalCode ?? '—'),
        _InstitutionColumn.number => _cellText(item.addressNumber ?? '—'),
        _InstitutionColumn.complement => _cellText(item.complement ?? '—'),
        _InstitutionColumn.district => _cellText(item.district ?? '—'),
        _InstitutionColumn.city => _cellText(item.city ?? '—'),
        _InstitutionColumn.state => _cellText(item.state ?? '—'),
      },
    );
  }

  Widget _cellText(String value) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _copyableContent(InstitutionDirectoryItem item, String kind, String label, String? value) {
    return Row(
      children: [
        Expanded(child: Text(value ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (value != null) ...[
          const SizedBox(width: CoeloSpacing.space1),
          _CopyValueButton(itemId: item.id, kind: kind, value: value, label: label),
        ],
      ],
    );
  }
}

class _CopyValueButton extends StatelessWidget {
  const _CopyValueButton({
    required this.itemId,
    required this.kind,
    required this.value,
    required this.label,
  });

  final String itemId;
  final String kind;
  final String value;
  final String label;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      key: Key('copy-$kind-$itemId'),
      onPressed: () => _copy(context),
      tooltip: 'Copiar $label',
      icon: const Icon(Icons.content_copy_rounded),
      iconSize: CoeloSize.iconSm,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: CoeloSpacing.space8,
        height: CoeloSpacing.space8,
      ),
      style: IconButton.styleFrom(
        foregroundColor: colors.onSurfaceVariant,
        backgroundColor: colors.surfaceContainer,
        minimumSize: const Size.square(CoeloSpacing.space8),
        maximumSize: const Size.square(CoeloSpacing.space8),
      ),
    );
  }
}

enum _InstitutionColumn {
  institution('institution', 'Instituição', 220, 180, InstitutionDirectorySortColumn.publicName),
  type('type', 'Tipo', 190, 140, InstitutionDirectorySortColumn.typeName),
  units('units', 'Unidades', 100, 88, InstitutionDirectorySortColumn.unitsCount),
  groups('groups', 'Grupos', 100, 88, InstitutionDirectorySortColumn.groupsCount),
  activities('activities', 'Atividades', 110, 96, null),
  legalRepresentatives('legal-representatives', 'Representantes legais', 180, 150, null),
  administrators('administrators', 'Administradores', 160, 140, null),
  team('team', 'Equipe institucional', 180, 150, null),
  guardians('guardians', 'Responsáveis', 140, 120, null),
  children('children', 'Crianças', 120, 100, null),
  plan('plan', 'Plano', 150, 120, InstitutionDirectorySortColumn.planName),
  status('status', 'Status', 150, 120, InstitutionDirectorySortColumn.status),
  email('email', 'E-mail', 240, 180, InstitutionDirectorySortColumn.contactEmail),
  phone('phone', 'Telefone', 200, 160, InstitutionDirectorySortColumn.contactPhone),
  mobile('mobile', 'Celular', 200, 160, InstitutionDirectorySortColumn.contactMobilePhone),
  domain('domain', 'Domínio', 220, 170, InstitutionDirectorySortColumn.primaryDomain),
  street('street', 'Logradouro', 220, 160, InstitutionDirectorySortColumn.street),
  number('number', 'Número', 110, 88, InstitutionDirectorySortColumn.addressNumber),
  complement('complement', 'Complemento', 170, 130, InstitutionDirectorySortColumn.complement),
  district('district', 'Bairro', 150, 120, InstitutionDirectorySortColumn.district),
  postalCode('postal-code', 'CEP', 130, 110, InstitutionDirectorySortColumn.postalCode),
  city('city', 'Município', 170, 130, InstitutionDirectorySortColumn.city),
  state('state', 'UF', 80, 64, InstitutionDirectorySortColumn.state);

  const _InstitutionColumn(
    this.id,
    this.label,
    this.initialWidth,
    this.minimumWidth,
    this.sortColumn,
  );

  final String id;
  final String label;
  final double initialWidth;
  final double minimumWidth;
  final InstitutionDirectorySortColumn? sortColumn;
}

enum _InstitutionDetailColumn {
  institution('institution', 'Instituição', 220, 180),
  unit('unit-name', 'Unidade', 220, 180),
  group('group-name', 'Grupo', 220, 180),
  activity('activity-name', 'Atividade', 220, 180),
  administrators('administrators', 'Administradores', 160, 140),
  team('team', 'Equipe institucional', 180, 150),
  guardians('guardians', 'Responsáveis', 140, 120),
  children('children', 'Crianças', 120, 100),
  status('status', 'Status', 150, 120);

  const _InstitutionDetailColumn(this.id, this.label, this.initialWidth, this.minimumWidth);

  final String id;
  final String label;
  final double initialWidth;
  final double minimumWidth;
}

typedef _InstitutionMetrics = ({
  int activities,
  int legalRepresentatives,
  int administrators,
  int team,
  int guardians,
  int children,
});

final class _InstitutionHierarchyRow {
  const _InstitutionHierarchyRow({
    required this.id,
    required this.institution,
    required this.unitName,
    required this.metrics,
    this.groupName,
    this.activityName,
  });

  final String id;
  final InstitutionDirectoryItem institution;
  final String unitName;
  final String? groupName;
  final String? activityName;
  final _InstitutionMetrics metrics;
}

List<_InstitutionHierarchyRow> _institutionHierarchyRows(
  List<InstitutionDirectoryItem> source,
  InstitutionDirectoryTableView level,
) {
  final institutions = [...source]
    ..sort((a, b) => a.publicName.toLowerCase().compareTo(b.publicName.toLowerCase()));
  final rows = <_InstitutionHierarchyRow>[];
  for (final institution in institutions) {
    final unitCount = institution.unitsCount.clamp(1, 4);
    final groupCount = institution.groupsCount.clamp(1, 12);
    final activityCount = _metricsFor(institution).activities.clamp(1, 18);
    if (level == InstitutionDirectoryTableView.units) {
      for (var unit = 0; unit < unitCount; unit++) {
        final id = '${institution.id}-u${unit + 1}';
        rows.add(
          _InstitutionHierarchyRow(
            id: id,
            institution: institution,
            unitName: 'Unidade ${(unit + 1).toString().padLeft(2, '0')}',
            metrics: _hierarchyMetrics(id),
          ),
        );
      }
      continue;
    }
    if (level == InstitutionDirectoryTableView.groups) {
      for (var group = 0; group < groupCount; group++) {
        final unit = group % unitCount;
        final id = '${institution.id}-u${unit + 1}-g${group + 1}';
        rows.add(
          _InstitutionHierarchyRow(
            id: id,
            institution: institution,
            unitName: 'Unidade ${(unit + 1).toString().padLeft(2, '0')}',
            groupName: 'Grupo ${(group + 1).toString().padLeft(2, '0')}',
            metrics: _hierarchyMetrics(id),
          ),
        );
      }
      continue;
    }
    for (var activity = 0; activity < activityCount; activity++) {
      final group = activity % groupCount;
      final unit = group % unitCount;
      final id = '${institution.id}-u${unit + 1}-g${group + 1}-a${activity + 1}';
      rows.add(
        _InstitutionHierarchyRow(
          id: id,
          institution: institution,
          unitName: 'Unidade ${(unit + 1).toString().padLeft(2, '0')}',
          groupName: 'Grupo ${(group + 1).toString().padLeft(2, '0')}',
          activityName: 'Atividade ${(activity + 1).toString().padLeft(2, '0')}',
          metrics: _hierarchyMetrics(id),
        ),
      );
    }
  }
  rows.sort((a, b) {
    final valuesA = [a.institution.publicName, a.unitName, a.groupName ?? '', a.activityName ?? ''];
    final valuesB = [b.institution.publicName, b.unitName, b.groupName ?? '', b.activityName ?? ''];
    for (var index = 0; index < valuesA.length; index++) {
      final comparison = valuesA[index].compareTo(valuesB[index]);
      if (comparison != 0) return comparison;
    }
    return 0;
  });
  return rows;
}

_InstitutionMetrics _hierarchyMetrics(String id) {
  final seed = id.codeUnits.fold<int>(0, (sum, value) => sum + value);
  return (
    activities: 1,
    legalRepresentatives: 1,
    administrators: 1 + seed % 2,
    team: 2 + seed % 5,
    guardians: 4 + seed % 9,
    children: 6 + seed % 12,
  );
}

_InstitutionMetrics _metricsFor(InstitutionDirectoryItem item) {
  final seed = item.id.codeUnits.fold<int>(0, (sum, value) => sum + value);
  return (
    activities: item.groupsCount * 3 + seed % 11,
    legalRepresentatives: 1 + seed % 2,
    administrators: 1 + (seed ~/ 2) % 3,
    team: item.groupsCount * 2 + seed % 5,
    guardians: item.groupsCount * 8 + seed % 7,
    children: item.groupsCount * 5 + seed % 9,
  );
}
