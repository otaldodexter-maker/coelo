import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart' show SuperadminExportFormat;
import '../../../app/shell/superadmin_notice.dart';
import '../domain/person_directory.dart';

typedef PersonExportAction =
    void Function(SuperadminExportFormat format, PersonDirectoryTableView tableView);

final class PersonFileActions extends StatelessWidget {
  const PersonFileActions({
    this.onImport,
    this.onExport,
    this.tableView = PersonDirectoryTableView.grouped,
    this.compact = false,
    super.key,
  });

  final VoidCallback? onImport;
  final PersonExportAction? onExport;
  final PersonDirectoryTableView tableView;
  final bool compact;

  @override
  Widget build(BuildContext context) => CoeloAdminFileActions(
    compact: compact,
    actions: personFileActions(
      context,
      onImport: onImport,
      onExport: onExport,
      tableView: tableView,
    ),
  );

  void _exportOrShowUnavailable(BuildContext context, SuperadminExportFormat format) {
    final export = onExport;
    if (export != null) {
      export(format, tableView);
      return;
    }
    _showUnavailable(context);
  }

  void _showUnavailable(BuildContext context) {
    showSuperadminNotice(context, 'Indisponível nesta etapa', icon: Icons.info_outline_rounded);
  }
}

/// Lista de ações de arquivo de Pessoas para o `CoeloAdminDirectory`.
List<CoeloAdminFileAction> personFileActions(
  BuildContext context, {
  VoidCallback? onImport,
  PersonExportAction? onExport,
  PersonDirectoryTableView tableView = PersonDirectoryTableView.grouped,
}) {
  final actions = PersonFileActions(onImport: onImport, onExport: onExport, tableView: tableView);
  return [
    CoeloAdminFileAction(
      key: const Key('people-files-import'),
      label: 'Importar',
      icon: Icons.upload_file_outlined,
      onPressed: onImport ?? () => actions._showUnavailable(context),
    ),
    CoeloAdminFileAction(
      key: const Key('people-files-export-csv'),
      label: 'Exportar CSV',
      icon: Icons.table_rows_outlined,
      onPressed: () => actions._exportOrShowUnavailable(context, SuperadminExportFormat.csv),
    ),
    CoeloAdminFileAction(
      key: const Key('people-files-export-xlsx'),
      label: 'Exportar XLSX',
      icon: Icons.grid_on_outlined,
      onPressed: () => actions._exportOrShowUnavailable(context, SuperadminExportFormat.xlsx),
    ),
  ];
}
