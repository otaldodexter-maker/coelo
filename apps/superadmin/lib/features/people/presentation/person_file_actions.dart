import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../domain/person_directory.dart';

final class PersonFileActions extends StatelessWidget {
  const PersonFileActions({
    required this.activityController,
    this.tableView = PersonDirectoryTableView.grouped,
    this.compact = false,
    super.key,
  });

  final SuperadminActivityController activityController;
  final PersonDirectoryTableView tableView;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    void export(SuperadminExportFormat format) {
      activityController.completeDemoExport(
        format,
        subject: 'Pessoas · ${tableView.label}',
        fileBaseName: 'pessoas',
      );
      showSuperadminNotice(
        context,
        'Preview de exportação: ${tableView.label}. Acompanhe pelo sininho.',
        icon: Icons.download_outlined,
      );
    }

    return CoeloAdminFileActions(
      compact: compact,
      actions: [
        CoeloAdminFileAction(
          key: const Key('people-files-import'),
          label: 'Importar',
          icon: Icons.upload_file_outlined,
          onPressed: () => _showImportDialog(context, activityController),
        ),
        CoeloAdminFileAction(
          key: const Key('people-files-export-csv'),
          label: 'Exportar CSV',
          icon: Icons.table_rows_outlined,
          onPressed: () => export(SuperadminExportFormat.csv),
        ),
        CoeloAdminFileAction(
          key: const Key('people-files-export-xlsx'),
          label: 'Exportar XLSX',
          icon: Icons.grid_on_outlined,
          onPressed: () => export(SuperadminExportFormat.xlsx),
        ),
      ],
    );
  }
}

Future<void> _showImportDialog(BuildContext context, SuperadminActivityController controller) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .54),
    builder: (dialogContext) =>
        _PersonImportDialog(activityController: controller, noticeContext: context),
  );
}

final class _PersonImportDialog extends StatefulWidget {
  const _PersonImportDialog({required this.activityController, required this.noticeContext});

  final SuperadminActivityController activityController;
  final BuildContext noticeContext;

  @override
  State<_PersonImportDialog> createState() => _PersonImportDialogState();
}

final class _PersonImportDialogState extends State<_PersonImportDialog> {
  var _fileSelected = false;
  var _reviewing = false;

  void _startImport() {
    widget.activityController.startDemoImport(
      subject: 'Pessoas',
      fileName: 'pessoas-julho.xlsx',
      progressSummary: 'Importando pessoas',
      completedSummary: '24 importadas, 2 rejeitadas',
    );
    showSuperadminNotice(
      widget.noticeContext,
      'A importação está em andamento. Acompanhe pelo sininho.',
      icon: Icons.upload_file_outlined,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CoeloAdminDialogShell(
      dialogKey: const Key('people-import-dialog'),
      closeButtonKey: const Key('people-import-close'),
      closeTooltip: 'Fechar importação',
      title: 'Importar pessoas',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _reviewing ? 'Etapa 2 de 2 · Revisar' : 'Etapa 1 de 2 · Arquivo',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.primary),
          ),
          const SizedBox(height: CoeloSpacing.space5),
          if (!_reviewing) ...[
            Text(
              'Use o modelo CSV ou XLSX de pessoas. Nesta demonstração nenhum arquivo real será enviado.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: CoeloSpacing.space4),
            OutlinedButton.icon(
              key: const Key('people-import-template-export'),
              onPressed: () => showSuperadminNotice(
                widget.noticeContext,
                'Modelo XLSX preparado para download demonstrativo.',
                icon: Icons.file_download_outlined,
              ),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Exportar modelo .xlsx'),
            ),
            const SizedBox(height: CoeloSpacing.space2),
            FilledButton.icon(
              key: const Key('people-demo-file-picker'),
              onPressed: () => setState(() => _fileSelected = true),
              icon: const Icon(Icons.file_open_outlined),
              label: Text(_fileSelected ? 'pessoas-julho.xlsx' : 'Importar arquivo'),
            ),
          ] else ...[
            _SummaryRow(
              icon: Icons.check_circle_outline,
              label: '24 linhas válidas',
              color: colors.primary,
            ),
            const SizedBox(height: CoeloSpacing.space2),
            _SummaryRow(icon: Icons.error_outline, label: '2 linhas com erro', color: colors.error),
            const SizedBox(height: CoeloSpacing.space3),
            Text(
              'As linhas com erro serão rejeitadas e as demais continuarão em segundo plano.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
      primaryAction: FilledButton(
        key: _reviewing ? const Key('people-import-confirm') : const Key('people-import-review'),
        onPressed: _reviewing
            ? _startImport
            : _fileSelected
            ? () => setState(() => _reviewing = true)
            : null,
        child: Text(_reviewing ? 'Importar 26 linhas' : 'Revisar arquivo'),
      ),
      secondaryAction: OutlinedButton(
        onPressed: _reviewing
            ? () => setState(() => _reviewing = false)
            : () => Navigator.of(context).pop(),
        child: Text(_reviewing ? 'Voltar' : 'Cancelar'),
      ),
    );
  }
}

final class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color),
      const SizedBox(width: CoeloSpacing.space2),
      Expanded(child: Text(label)),
    ],
  );
}
