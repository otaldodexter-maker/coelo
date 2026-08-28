import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../../app/activity/superadmin_activity.dart';
import '../../../../app/shell/superadmin_notice.dart';

/// Fail-closed placeholder until institution import/export has a production
/// gateway, worker identity, private Storage lifecycle, and integrated tests.
class InstitutionFileActions extends StatelessWidget {
  const InstitutionFileActions({required this.activityController, this.compact = false, super.key});

  final SuperadminActivityController activityController;
  final bool compact;

  @override
  Widget build(BuildContext context) => CoeloAdminFileActions(
    compact: compact,
    actions: [
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
    ],
  );

  void _showUnavailable(BuildContext context) {
    showSuperadminNotice(context, 'Indisponível nesta etapa', icon: Icons.info_outline_rounded);
  }
}
