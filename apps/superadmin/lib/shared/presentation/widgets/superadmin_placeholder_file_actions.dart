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
    actions: [
      CoeloAdminFileAction(
        label: 'Importar arquivo',
        icon: Icons.upload_file_outlined,
        onPressed: () => _showUnavailable(context, 'Importação'),
      ),
      CoeloAdminFileAction(
        label: 'Exportar CSV',
        icon: Icons.table_rows_outlined,
        onPressed: () => _showUnavailable(context, 'Exportação CSV'),
      ),
      CoeloAdminFileAction(
        label: 'Exportar XLSX',
        icon: Icons.grid_on_outlined,
        onPressed: () => _showUnavailable(context, 'Exportação XLSX'),
      ),
    ],
  );

  void _showUnavailable(BuildContext context, String operation) {
    showSuperadminNotice(
      context,
      '$operation de $resourceLabel estará disponível em breve.',
      icon: Icons.info_outline_rounded,
    );
  }
}
