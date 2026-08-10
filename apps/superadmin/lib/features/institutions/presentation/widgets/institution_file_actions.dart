import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../../app/activity/superadmin_activity.dart';
import '../../../../app/shell/superadmin_notice.dart';

class InstitutionFileActions extends StatelessWidget {
  const InstitutionFileActions({
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
        subject: label == null ? 'Instituições' : 'Instituições · $label',
        fileBaseName: label == null ? 'instituicoes' : 'instituicoes-${_viewFileSuffix(label)}',
      );
      showSuperadminNotice(
        context,
        'A exportação está em andamento. Acompanhe pelo sininho.',
        icon: Icons.download_outlined,
      );
    }

    return KeyedSubtree(
      key: const Key('institution-files-action'),
      child: CoeloAdminFileActions(
        compact: compact,
        actions: [
          CoeloAdminFileAction(
            key: const Key('institution-files-import'),
            label: 'Importar',
            icon: Icons.upload_file_outlined,
            onPressed: () => _showImportDialog(context, activityController),
          ),
          CoeloAdminFileAction(
            key: const Key('institution-files-export-csv'),
            label: 'Exportar CSV',
            icon: Icons.table_rows_outlined,
            onPressed: () => export(SuperadminExportFormat.csv),
          ),
          CoeloAdminFileAction(
            key: const Key('institution-files-export-xlsx'),
            label: 'Exportar XLSX',
            icon: Icons.grid_on_outlined,
            onPressed: () => export(SuperadminExportFormat.xlsx),
          ),
        ],
      ),
    );
  }
}

String _viewFileSuffix(String value) => switch (value) {
  'Atividades' => 'atividades',
  'Agrupado' => 'agrupado',
  'Unidades' => 'unidades',
  'Turmas' => 'turmas',
  'Grupos' => 'grupos',
  'Cards' => 'cards',
  _ => 'visao',
};

Future<void> _showImportDialog(BuildContext context, SuperadminActivityController controller) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.54),
    builder: (dialogContext) =>
        _InstitutionImportDialog(activityController: controller, noticeContext: context),
  );
}

void _showTemplateDownload(BuildContext context, String message) {
  showSuperadminNotice(context, message, icon: Icons.file_download_outlined);
}

class _InstitutionImportDialog extends StatefulWidget {
  const _InstitutionImportDialog({
    required this.activityController,
    this.initialReview = false,
    this.noticeContext,
  });

  final SuperadminActivityController activityController;
  final bool initialReview;
  final BuildContext? noticeContext;

  @override
  State<_InstitutionImportDialog> createState() => _InstitutionImportDialogState();
}

class _InstitutionImportDialogState extends State<_InstitutionImportDialog> {
  late var _fileSelected = widget.initialReview;
  late var _reviewing = widget.initialReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final noticeContext = widget.noticeContext ?? context;
    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Importar instituições', style: theme.textTheme.headlineSmall),
                  ),
                  IconButton(
                    tooltip: 'Fechar importação',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(foregroundColor: colors.error),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: CoeloSpacing.space2),
              Text(
                _reviewing ? 'Etapa 2 de 2 · Revisar' : 'Etapa 1 de 2 · Arquivo',
                style: theme.textTheme.labelLarge?.copyWith(color: colors.primary),
              ),
              const SizedBox(height: CoeloSpacing.space5),
              if (!_reviewing) ...[
                Text(
                  'Use o modelo CSV ou XLSX de instituições para preparar o arquivo de importação.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: CoeloSpacing.space4),
                OutlinedButton.icon(
                  key: const Key('institution-import-template-export'),
                  onPressed: () =>
                      _showTemplateDownload(noticeContext, 'Modelo XLSX pronto para download.'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                  ),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Exportar modelo .xlsx'),
                ),
                const SizedBox(height: CoeloSpacing.space2),
                FilledButton.icon(
                  key: const Key('institution-demo-file-picker'),
                  onPressed: () => setState(() => _fileSelected = true),
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(_fileSelected ? 'instituicoes-julho.xlsx' : 'Importar arquivo'),
                ),
                if (_fileSelected) ...[
                  const SizedBox(height: CoeloSpacing.space4),
                  FilledButton(
                    key: const Key('institution-import-review'),
                    onPressed: () => setState(() => _reviewing = true),
                    child: const Text('Revisar arquivo'),
                  ),
                ],
              ] else ...[
                _ImportSummaryRow(
                  icon: Icons.check_circle_outline,
                  label: '24 linhas válidas',
                  color: colors.primary,
                ),
                const SizedBox(height: CoeloSpacing.space2),
                _ImportSummaryRow(
                  icon: Icons.error_outline,
                  label: '2 linhas com erro',
                  color: colors.error,
                ),
                const SizedBox(height: CoeloSpacing.space3),
                Text(
                  'As linhas com erro serão rejeitadas e as demais continuarão em segundo plano.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: CoeloSpacing.space5),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: CoeloSpacing.space2,
                  overflowAlignment: OverflowBarAlignment.end,
                  overflowSpacing: CoeloSpacing.space2,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _reviewing = false),
                      child: const Text('Voltar'),
                    ),
                    FilledButton(
                      key: const Key('institution-import-confirm'),
                      onPressed: () {
                        widget.activityController.startDemoImport();
                        showSuperadminNotice(
                          noticeContext,
                          'A importação está em andamento. Acompanhe pelo sininho.',
                          icon: Icons.upload_file_outlined,
                        );
                        Navigator.of(context).pop();
                      },
                      child: const Text('Importar 26 linhas'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportSummaryRow extends StatelessWidget {
  const _ImportSummaryRow({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
      ],
    );
  }
}

final _fileActionsPreviewController = SuperadminActivityController();

@Preview(name: 'Ações de arquivo · desktop · light', size: Size(320, 64))
Widget institutionFileActionsPreview() {
  return _fileActionsPreview(compact: false, theme: CoeloTheme.light);
}

@Preview(name: 'Ações de arquivo · desktop · dark', size: Size(320, 64))
Widget institutionFileActionsDarkPreview() {
  return _fileActionsPreview(compact: false, theme: CoeloTheme.dark);
}

@Preview(name: 'Ações de arquivo · compacta · light', size: Size(72, 64))
Widget institutionFileActionsCompactLightPreview() {
  return _fileActionsPreview(compact: true, theme: CoeloTheme.light);
}

@Preview(name: 'Ações de arquivo · compacta · dark', size: Size(72, 64))
Widget institutionFileActionsCompactDarkPreview() {
  return _fileActionsPreview(compact: true, theme: CoeloTheme.dark);
}

Widget _fileActionsPreview({required bool compact, required ThemeData theme}) {
  return MaterialApp(
    key: ValueKey((compact, theme.brightness)),
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: Scaffold(
      body: Center(
        child: InstitutionFileActions(
          activityController: _fileActionsPreviewController,
          compact: compact,
        ),
      ),
    ),
  );
}

@Preview(name: 'Importação · selecionar arquivo · light', size: Size(600, 420))
Widget institutionImportSelectPreview() {
  return _importDialogPreview(reviewing: false, theme: CoeloTheme.light);
}

@Preview(name: 'Importação · selecionar arquivo · dark', size: Size(600, 420))
Widget institutionImportSelectDarkPreview() {
  return _importDialogPreview(reviewing: false, theme: CoeloTheme.dark);
}

@Preview(name: 'Importação · revisão · light', size: Size(600, 460))
Widget institutionImportReviewLightPreview() {
  return _importDialogPreview(reviewing: true, theme: CoeloTheme.light);
}

@Preview(name: 'Importação · revisão · dark', size: Size(600, 460))
Widget institutionImportReviewDarkPreview() {
  return _importDialogPreview(reviewing: true, theme: CoeloTheme.dark);
}

Widget _importDialogPreview({required bool reviewing, required ThemeData theme}) {
  return MaterialApp(
    key: ValueKey((reviewing, theme.brightness)),
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: Scaffold(
      body: Center(
        child: _InstitutionImportDialog(
          activityController: _fileActionsPreviewController,
          initialReview: reviewing,
        ),
      ),
    ),
  );
}
