import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_notice.dart';

final class AuditExportActions extends StatelessWidget {
  const AuditExportActions({required this.compact, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) => CoeloAdminFileActions(
    compact: compact,
    actions: [
      CoeloAdminFileAction(
        label: 'Exportar CSV',
        icon: Icons.table_view_outlined,
        onPressed: () => showSuperadminNotice(context, 'Disponível depois do MVP'),
      ),
      CoeloAdminFileAction(
        label: 'Exportar XLSX',
        icon: Icons.grid_on_outlined,
        onPressed: () => showSuperadminNotice(context, 'Disponível depois do MVP'),
      ),
    ],
  );
}
