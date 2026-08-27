import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart' show SuperadminExportFormat;
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
  Widget build(BuildContext context) {
    if (onImport == null && onExport == null) return const SizedBox.shrink();

    return CoeloAdminFileActions(
      compact: compact,
      actions: [
        if (onImport != null)
          CoeloAdminFileAction(
            key: const Key('people-files-import'),
            label: 'Importar',
            icon: Icons.upload_file_outlined,
            onPressed: onImport!,
          ),
        if (onExport != null) ...[
          CoeloAdminFileAction(
            key: const Key('people-files-export-csv'),
            label: 'Exportar CSV',
            icon: Icons.table_rows_outlined,
            onPressed: () => onExport!(SuperadminExportFormat.csv, tableView),
          ),
          CoeloAdminFileAction(
            key: const Key('people-files-export-xlsx'),
            label: 'Exportar XLSX',
            icon: Icons.grid_on_outlined,
            onPressed: () => onExport!(SuperadminExportFormat.xlsx, tableView),
          ),
        ],
      ],
    );
  }
}
