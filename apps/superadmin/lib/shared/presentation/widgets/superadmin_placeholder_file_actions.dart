import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_notice.dart';

/// Honest file actions for directories whose import/export gateway is pending.
///
/// The actions are visible by product contract, but always explain that no file
/// was processed until the corresponding backend workflow is connected.
final class SuperadminPlaceholderFileActions extends StatelessWidget {
  const SuperadminPlaceholderFileActions({
    required this.resourceLabel,
    this.compact = true,
    super.key,
  });

  final String resourceLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) => CoeloAdminFileActions(
    compact: compact,
    actions: superadminPlaceholderFileActionList(context, resourceLabel),
  );
}

/// Lista de ações honestas de arquivo para o `CoeloAdminDirectory`.
List<CoeloAdminFileAction> superadminPlaceholderFileActionList(
  BuildContext context,
  String resourceLabel,
) {
  void showUnavailable(String operation) {
    showSuperadminNotice(
      context,
      '$operation de $resourceLabel estará disponível em breve.',
      icon: Icons.info_outline_rounded,
    );
  }

  return [
    CoeloAdminFileAction(
      label: 'Importar arquivo',
      icon: Icons.upload_file_outlined,
      onPressed: () => showUnavailable('Importação'),
    ),
    CoeloAdminFileAction(
      label: 'Exportar CSV',
      icon: Icons.table_rows_outlined,
      onPressed: () => showUnavailable('Exportação CSV'),
    ),
    CoeloAdminFileAction(
      label: 'Exportar XLSX',
      icon: Icons.grid_on_outlined,
      onPressed: () => showUnavailable('Exportação XLSX'),
    ),
  ];
}
