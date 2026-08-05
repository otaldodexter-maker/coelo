import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_notice.dart';

final class HealthCareFileActions extends StatelessWidget {
  const HealthCareFileActions({
    required this.activityController,
    required this.subject,
    required this.fileBaseName,
    this.compact = false,
    super.key,
  });

  final SuperadminActivityController activityController;
  final String subject;
  final String fileBaseName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    void export(SuperadminExportFormat format) {
      activityController.completeDemoExport(
        format,
        subject: subject,
        fileBaseName: fileBaseName,
      );
      showSuperadminNotice(
        context,
        'Exportação demonstrativa preparada. Acompanhe pelo sininho.',
        icon: Icons.download_outlined,
      );
    }

    return CoeloAdminFileActions(
      compact: compact,
      actions: [
        CoeloAdminFileAction(
          key: const Key('health-care-files-import'),
          label: 'Importar',
          icon: Icons.upload_file_outlined,
          onPressed: () => _showImportDialog(
            context,
            activityController: activityController,
            subject: subject,
          ),
        ),
        CoeloAdminFileAction(
          key: const Key('health-care-files-export-csv'),
          label: 'Exportar CSV',
          icon: Icons.table_rows_outlined,
          onPressed: () => export(SuperadminExportFormat.csv),
        ),
        CoeloAdminFileAction(
          key: const Key('health-care-files-export-xlsx'),
          label: 'Exportar XLSX',
          icon: Icons.grid_on_outlined,
          onPressed: () => export(SuperadminExportFormat.xlsx),
        ),
      ],
    );
  }
}

Future<void> _showImportDialog(
  BuildContext context, {
  required SuperadminActivityController activityController,
  required String subject,
}) => showDialog<void>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: .54),
  builder: (dialogContext) => CoeloAdminDialogShell(
    dialogKey: const Key('health-care-import-dialog'),
    closeButtonKey: const Key('health-care-import-close'),
    closeTooltip: 'Fechar importação',
    title: 'Importar $subject',
    body: const Text(
      'Use um arquivo CSV ou XLSX. Nesta demonstração nenhum dado real será enviado.',
    ),
    primaryAction: FilledButton(
      key: const Key('health-care-import-confirm'),
      onPressed: () {
        activityController.startDemoImport(
          subject: subject,
          fileName: 'saude-e-cuidado.xlsx',
          progressSummary: 'Importando Saúde e Cuidado',
          completedSummary: 'Importação demonstrativa concluída',
        );
        Navigator.of(dialogContext).pop();
        showSuperadminNotice(
          context,
          'A importação demonstrativa começou. Acompanhe pelo sininho.',
          icon: Icons.upload_file_outlined,
        );
      },
      child: const Text('Importar arquivo'),
    ),
    secondaryAction: OutlinedButton(
      onPressed: () => Navigator.of(dialogContext).pop(),
      child: const Text('Cancelar'),
    ),
  ),
);
