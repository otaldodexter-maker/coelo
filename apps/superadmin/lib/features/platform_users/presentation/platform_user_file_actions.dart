import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

final class PlatformUserFileActions extends StatelessWidget {
  const PlatformUserFileActions({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) => CoeloAdminFileActions(
    compact: compact,
    actions: [
      CoeloAdminFileAction(
        key: const Key('platform-user-files-import'),
        label: 'Importar',
        icon: Icons.upload_file_outlined,
        onPressed: null,
      ),
      CoeloAdminFileAction(
        key: const Key('platform-user-files-export-csv'),
        label: 'Exportar CSV',
        icon: Icons.table_rows_outlined,
        onPressed: null,
      ),
      CoeloAdminFileAction(
        key: const Key('platform-user-files-export-xlsx'),
        label: 'Exportar XLSX',
        icon: Icons.grid_on_outlined,
        onPressed: null,
      ),
    ],
  );
}
