import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

final class HealthCareFileActions extends StatelessWidget {
  const HealthCareFileActions({
    this.onImport,
    this.onExportCsv,
    this.onExportXlsx,
    this.compact = false,
    super.key,
  });

  final VoidCallback? onImport;
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportXlsx;
  final bool compact;

  bool get _hasAvailableAction => onImport != null || onExportCsv != null || onExportXlsx != null;

  @override
  Widget build(BuildContext context) {
    if (!_hasAvailableAction) {
      return Tooltip(
        message: 'Importação e exportação indisponíveis',
        child: compact
            ? const IconButton(
                key: Key('coelo-admin-files-action'),
                tooltip: 'Arquivos indisponíveis',
                onPressed: null,
                icon: Icon(Icons.folder_open_outlined),
              )
            : OutlinedButton.icon(
                key: const Key('coelo-admin-files-action'),
                onPressed: null,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Arquivos'),
              ),
      );
    }

    return CoeloAdminFileActions(
      compact: compact,
      actions: [
        if (onImport != null)
          CoeloAdminFileAction(
            key: const Key('health-care-files-import'),
            label: 'Importar',
            icon: Icons.upload_file_outlined,
            onPressed: onImport!,
          ),
        if (onExportCsv != null)
          CoeloAdminFileAction(
            key: const Key('health-care-files-export-csv'),
            label: 'Exportar CSV',
            icon: Icons.table_rows_outlined,
            onPressed: onExportCsv!,
          ),
        if (onExportXlsx != null)
          CoeloAdminFileAction(
            key: const Key('health-care-files-export-xlsx'),
            label: 'Exportar XLSX',
            icon: Icons.grid_on_outlined,
            onPressed: onExportXlsx!,
          ),
      ],
    );
  }
}
