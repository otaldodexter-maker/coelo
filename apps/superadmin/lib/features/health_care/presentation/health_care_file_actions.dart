import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_notice.dart';

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

  @override
  Widget build(BuildContext context) {
    return CoeloAdminFileActions(
      compact: compact,
      actions: [
        CoeloAdminFileAction(
          key: const Key('health-care-files-import'),
          label: 'Importar',
          icon: Icons.upload_file_outlined,
          onPressed: onImport ?? () => _showUnavailable(context),
        ),
        CoeloAdminFileAction(
          key: const Key('health-care-files-export-csv'),
          label: 'Exportar CSV',
          icon: Icons.table_rows_outlined,
          onPressed: onExportCsv ?? () => _showUnavailable(context),
        ),
        CoeloAdminFileAction(
          key: const Key('health-care-files-export-xlsx'),
          label: 'Exportar XLSX',
          icon: Icons.grid_on_outlined,
          onPressed: onExportXlsx ?? () => _showUnavailable(context),
        ),
      ],
    );
  }

  void _showUnavailable(BuildContext context) {
    showSuperadminNotice(context, 'Indisponível nesta etapa', icon: Icons.info_outline_rounded);
  }
}
