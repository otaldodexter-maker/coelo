import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/institution_directory_item.dart';
import '../../domain/institution_directory_query.dart';
import 'institution_status_presentation.dart';

class InstitutionDirectoryTable extends StatelessWidget {
  const InstitutionDirectoryTable({
    required this.items,
    required this.createAction,
    required this.onEdit,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    super.key,
  });

  final List<InstitutionDirectoryItem> items;
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
            SizedBox(
              key: const Key('institution-directory-table-viewport'),
              width: constraints.maxWidth,
              child: CoeloAdminResizableTable<InstitutionDirectoryItem>(
                key: const Key('institution-directory-table'),
                items: items,
                rowKey: (item) => 'institution-table-row-${item.id}',
                pinnedColumn: _column(_InstitutionColumn.institution),
                columns: _InstitutionColumn.values.skip(1).map(_column).toList(growable: false),
                headerHeight: 56,
                rowHeight: 64,
                onRowPressed: onEdit,
                sortColumnId: _InstitutionColumn.values
                    .firstWhere((column) => column.sortColumn == sortColumn)
                    .id,
                sortAscending: sortAscending,
                onSort: (id) => onSort(
                  _InstitutionColumn.values.firstWhere((column) => column.id == id).sortColumn!,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

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
