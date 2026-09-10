import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_notice.dart';

/// Ações de arquivo de Saúde e Cuidado para o `CoeloAdminDirectory`. Sem
/// gateway, cada ação avisa que ainda está indisponível.
List<CoeloAdminFileAction> healthCareFileActions(
  BuildContext context, {
  VoidCallback? onImport,
  VoidCallback? onExportCsv,
  VoidCallback? onExportXlsx,
}) {
  void showUnavailable() {
    showSuperadminNotice(context, 'Indisponível nesta etapa', icon: Icons.info_outline_rounded);
  }

  return [
    CoeloAdminFileAction(
      key: const Key('health-care-files-import'),
      label: 'Importar',
      icon: Icons.upload_file_outlined,
      onPressed: onImport ?? showUnavailable,
    ),
    CoeloAdminFileAction(
      key: const Key('health-care-files-export-csv'),
      label: 'Exportar CSV',
      icon: Icons.table_rows_outlined,
      onPressed: onExportCsv ?? showUnavailable,
    ),
    CoeloAdminFileAction(
      key: const Key('health-care-files-export-xlsx'),
      label: 'Exportar XLSX',
      icon: Icons.grid_on_outlined,
      onPressed: onExportXlsx ?? showUnavailable,
    ),
  ];
}

/// Compatibilidade para superfícies que ainda montam o menu diretamente.
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
  Widget build(BuildContext context) => CoeloAdminFileActions(
    compact: compact,
    actions: healthCareFileActions(
      context,
      onImport: onImport,
      onExportCsv: onExportCsv,
      onExportXlsx: onExportXlsx,
    ),
  );
}
