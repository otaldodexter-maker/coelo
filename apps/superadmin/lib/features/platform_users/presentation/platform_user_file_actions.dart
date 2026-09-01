import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_notice.dart';

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
        onPressed: () => _unavailable(context),
      ),
      CoeloAdminFileAction(
        key: const Key('platform-user-files-export-csv'),
        label: 'Exportar CSV',
        icon: Icons.table_rows_outlined,
        onPressed: () => _unavailable(context),
      ),
      CoeloAdminFileAction(
        key: const Key('platform-user-files-export-xlsx'),
        label: 'Exportar XLSX',
        icon: Icons.grid_on_outlined,
        onPressed: () => _unavailable(context),
      ),
    ],
  );

  void _unavailable(BuildContext context) {
    showSuperadminNotice(context, 'Indisponível nesta etapa', icon: Icons.info_outline_rounded);
  }
}
