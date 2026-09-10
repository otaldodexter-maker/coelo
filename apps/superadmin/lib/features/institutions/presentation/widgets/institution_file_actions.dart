import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_notice.dart';

/// Ações de arquivo de Instituições. Import/export continuam adiados no MVP
/// (botão visível e indisponibilidade honesta).
List<CoeloAdminFileAction> institutionFileActions(BuildContext context) => [
  CoeloAdminFileAction(
    key: const Key('institution-files-import'),
    label: 'Importar',
    icon: Icons.upload_file_outlined,
    onPressed: () => _showUnavailable(context),
  ),
  CoeloAdminFileAction(
    key: const Key('institution-files-export-csv'),
    label: 'Exportar CSV',
    icon: Icons.table_rows_outlined,
    onPressed: () => _showUnavailable(context),
  ),
  CoeloAdminFileAction(
    key: const Key('institution-files-export-xlsx'),
    label: 'Exportar XLSX',
    icon: Icons.grid_on_outlined,
    onPressed: () => _showUnavailable(context),
  ),
];

void _showUnavailable(BuildContext context) {
  showSuperadminNotice(context, 'Indisponível nesta etapa', icon: Icons.info_outline_rounded);
}
