import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_notice.dart';

/// Ações de arquivo de Instituições. Importação e exportação estão fora do
/// MVP (ADR 0041 A4): o flyout permanece na tela e, ao clicar, informa que a
/// função está em desenvolvimento; nada é importado ou exportado.
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

/// Texto único do aviso, também usado pelos testes de widget.
const institutionFilesInDevelopmentMessage =
    'Arquivos em desenvolvimento: importar e exportar instituições chegam depois do MVP.';

void _showUnavailable(BuildContext context) {
  showSuperadminNotice(
    context,
    institutionFilesInDevelopmentMessage,
    icon: Icons.construction_outlined,
  );
}
