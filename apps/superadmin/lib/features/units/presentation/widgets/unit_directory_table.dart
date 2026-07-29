import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/unit_directory.dart';
import 'unit_status_presentation.dart';

final class UnitDirectoryTable extends StatelessWidget {
  const UnitDirectoryTable({
    required this.items,
    required this.createAction,
    required this.onEdit,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    super.key,
  });

  final List<UnitDirectoryItem> items;
  final Widget createAction;
  final ValueChanged<UnitDirectoryItem> onEdit;
  final UnitDirectorySortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<UnitDirectorySortColumn> onSort;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          SizedBox(width: constraints.maxWidth, child: createAction),
          const SizedBox(height: CoeloSpacing.space4),
          SizedBox(
            key: const Key('unit-directory-table-viewport'),
            width: constraints.maxWidth,
            child: CoeloAdminResizableTable<UnitDirectoryItem>(
              key: const Key('unit-directory-table'),
              items: items,
              rowKey: (item) => 'unit-table-row-${item.id}',
              pinnedColumn: _column(_UnitColumn.unit),
              columns: _UnitColumn.values.skip(1).map(_column).toList(growable: false),
              headerHeight: 56,
              rowHeight: 64,
              onRowPressed: onEdit,
              sortColumnId: _UnitColumn.values
                  .firstWhere((column) => column.sortColumn == sortColumn)
                  .id,
              sortAscending: sortAscending,
              onSort: (id) =>
                  onSort(_UnitColumn.values.firstWhere((column) => column.id == id).sortColumn),
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
      sortable: true,
      cellBuilder: (context, item) => switch (column) {
        _UnitColumn.unit => _unitCell(context, item),
        _UnitColumn.institution => _text(item.institutionName),
        _UnitColumn.type => _text(item.typeName),
        _UnitColumn.groups => _text('${item.groupsCount}'),
        _UnitColumn.activities => _text('${item.activitiesCount}'),
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

enum _UnitColumn {
  unit('unit', 'Unidade', 220, 180, UnitDirectorySortColumn.name),
  institution('institution', 'Instituição', 220, 180, UnitDirectorySortColumn.institutionName),
  type('type', 'Tipo', 190, 140, UnitDirectorySortColumn.typeName),
  groups('groups', 'Grupos', 100, 88, UnitDirectorySortColumn.groupsCount),
  activities('activities', 'Atividades', 110, 96, UnitDirectorySortColumn.activitiesCount),
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
  final UnitDirectorySortColumn sortColumn;
}
