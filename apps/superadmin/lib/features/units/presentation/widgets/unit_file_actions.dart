import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../../app/activity/superadmin_activity.dart';
import '../../../../app/shell/superadmin_notice.dart';

final class UnitFileActions extends StatelessWidget {
  const UnitFileActions({
    required this.activityController,
    this.compact = false,
    this.viewLabel,
    super.key,
  });

  final SuperadminActivityController activityController;
  final bool compact;
  final String? viewLabel;

  @override
  Widget build(BuildContext context) {
    void export(SuperadminExportFormat format) {
      final label = viewLabel;
      activityController.completeDemoExport(
        format,
        subject: label == null ? 'Unidades' : 'Unidades · $label',
        fileBaseName: label == null ? 'unidades' : 'unidades-${_viewSuffix(label)}',
      );
      showSuperadminNotice(
        context,
        'A exportação está em andamento. Acompanhe pelo sininho.',
        icon: Icons.download_outlined,
      );
    }

    return CoeloAdminFileActions(
      compact: compact,
      actions: [
        CoeloAdminFileAction(
          key: const Key('unit-files-import'),
          label: 'Importar',
          icon: Icons.upload_file_outlined,
          onPressed: () => _showImportDialog(context, activityController),
        ),
        CoeloAdminFileAction(
          key: const Key('unit-files-export-csv'),
          label: 'Exportar CSV',
          icon: Icons.table_rows_outlined,
          onPressed: () => export(SuperadminExportFormat.csv),
        ),
        CoeloAdminFileAction(
          key: const Key('unit-files-export-xlsx'),
          label: 'Exportar XLSX',
          icon: Icons.grid_on_outlined,
          onPressed: () => export(SuperadminExportFormat.xlsx),
        ),
      ],
    );
  }
}

String _viewSuffix(String label) => switch (label) {
  'Cards' => 'cards',
  'Agrupado' => 'agrupado',
  'Por grupos' => 'por-grupos',
  'Por atividades' => 'por-atividades',
  _ => 'visao',
};

Future<void> _showImportDialog(BuildContext context, SuperadminActivityController controller) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .54),
    builder: (dialogContext) =>
        _UnitImportDialog(activityController: controller, noticeContext: context),
  );
}

final class _UnitImportDialog extends StatefulWidget {
  const _UnitImportDialog({required this.activityController, required this.noticeContext});

  final SuperadminActivityController activityController;
  final BuildContext noticeContext;

  @override
  State<_UnitImportDialog> createState() => _UnitImportDialogState();
}

final class _UnitImportDialogState extends State<_UnitImportDialog> {
  bool _fileSelected = false;
  bool _reviewing = false;

  void _startImport() {
    widget.activityController.startDemoImport(
      subject: 'Unidades',
      fileName: 'unidades-julho.xlsx',
      progressSummary: 'Importando unidades',
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
      dialogKey: const Key('unit-import-dialog'),
      closeButtonKey: const Key('unit-import-close'),
      closeTooltip: 'Fechar importação',
      title: 'Importar unidades',
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
              'Use o modelo CSV ou XLSX de unidades. Nesta demonstração nenhum arquivo real será enviado.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: CoeloSpacing.space4),
            OutlinedButton.icon(
              key: const Key('unit-demo-file-picker'),
              onPressed: () => setState(() => _fileSelected = true),
              icon: const Icon(Icons.file_open_outlined),
              label: Text(_fileSelected ? 'unidades-julho.xlsx' : 'Selecionar arquivo'),
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
        key: _reviewing ? const Key('unit-import-confirm') : const Key('unit-import-review'),
        onPressed: _reviewing
            ? _startImport
            : _fileSelected
            ? () => setState(() => _reviewing = true)
            : null,
        child: Text(_reviewing ? 'Importar 26 linhas' : 'Revisar arquivo'),
      ),
      secondaryAction: OutlinedButton(
        key: _reviewing ? const Key('unit-import-back') : const Key('unit-import-template-export'),
        onPressed: _reviewing
            ? () => setState(() => _reviewing = false)
            : () => showSuperadminNotice(
                widget.noticeContext,
                'Modelo XLSX preparado para download demonstrativo.',
                icon: Icons.file_download_outlined,
              ),
        child: Text(_reviewing ? 'Voltar' : 'Exportar modelo .xlsx'),
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
