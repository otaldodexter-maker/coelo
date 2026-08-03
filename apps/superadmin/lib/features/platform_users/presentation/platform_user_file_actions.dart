import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_notice.dart';

final class PlatformUserFileActions extends StatelessWidget {
  const PlatformUserFileActions({required this.compact, required this.viewLabel, super.key});

  final bool compact;
  final String viewLabel;

  @override
  Widget build(BuildContext context) {
    void export(String format) {
      showSuperadminNotice(
        context,
        'Exportação $format preparada somente no preview (visão: $viewLabel). '
        'Nenhum arquivo real foi gerado.',
        icon: Icons.download_outlined,
      );
    }

    return CoeloAdminFileActions(
      compact: compact,
      actions: [
        CoeloAdminFileAction(
          key: const Key('platform-user-files-import'),
          label: 'Importar',
          icon: Icons.upload_file_outlined,
          onPressed: () => _showImportDialog(context),
        ),
        CoeloAdminFileAction(
          key: const Key('platform-user-files-export-csv'),
          label: 'Exportar CSV',
          icon: Icons.table_rows_outlined,
          onPressed: () => export('CSV'),
        ),
        CoeloAdminFileAction(
          key: const Key('platform-user-files-export-xlsx'),
          label: 'Exportar XLSX',
          icon: Icons.grid_on_outlined,
          onPressed: () => export('XLSX'),
        ),
      ],
    );
  }
}

Future<void> _showImportDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.54),
    builder: (dialogContext) => _PlatformUserImportDialog(noticeContext: context),
  );
}

final class _PlatformUserImportDialog extends StatefulWidget {
  const _PlatformUserImportDialog({required this.noticeContext});

  final BuildContext noticeContext;

  @override
  State<_PlatformUserImportDialog> createState() => _PlatformUserImportDialogState();
}

final class _PlatformUserImportDialogState extends State<_PlatformUserImportDialog> {
  var _fileSelected = false;
  var _reviewing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return CoeloAdminDialogShell(
      dialogKey: const Key('platform-user-import-dialog'),
      closeButtonKey: const Key('platform-user-import-close'),
      closeTooltip: 'Fechar importação',
      title: 'Importar usuários internos',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _reviewing ? 'Etapa 2 de 2 · Revisar' : 'Etapa 1 de 2 · Arquivo',
            style: theme.textTheme.labelLarge?.copyWith(color: colors.primary),
          ),
          const SizedBox(height: CoeloSpacing.space5),
          if (!_reviewing) ...[
            Text(
              'Use o modelo CSV ou XLSX de usuários internos. Neste preview nenhum arquivo real será enviado.',
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: CoeloSpacing.space4),
            OutlinedButton.icon(
              key: const Key('platform-user-import-template-export'),
              onPressed: () => showSuperadminNotice(
                widget.noticeContext,
                'Modelo XLSX preparado somente no preview. Nenhum arquivo real foi gerado.',
                icon: Icons.file_download_outlined,
              ),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Exportar modelo .xlsx'),
            ),
            const SizedBox(height: CoeloSpacing.space2),
            FilledButton.icon(
              key: const Key('platform-user-demo-file-picker'),
              onPressed: () => setState(() => _fileSelected = true),
              icon: const Icon(Icons.file_open_outlined),
              label: Text(_fileSelected ? 'usuarios-internos-preview.xlsx' : 'Selecionar arquivo'),
            ),
          ] else ...[
            _ImportSummaryRow(
              icon: Icons.check_circle_outline,
              label: '12 linhas válidas',
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
              'Esta revisão é demonstrativa. Nenhum usuário, identidade, papel ou convite será alterado.',
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
      secondaryAction: _reviewing
          ? OutlinedButton(
              onPressed: () => setState(() => _reviewing = false),
              child: const Text('Voltar'),
            )
          : OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
      primaryAction: _reviewing
          ? FilledButton(
              key: const Key('platform-user-import-confirm'),
              onPressed: () {
                Navigator.of(context).pop();
                showSuperadminNotice(
                  widget.noticeContext,
                  'Importação concluída somente no preview. Nenhum usuário real foi alterado.',
                  icon: Icons.upload_file_outlined,
                );
              },
              child: const Text('Confirmar preview'),
            )
          : FilledButton(
              key: const Key('platform-user-import-review'),
              onPressed: _fileSelected ? () => setState(() => _reviewing = true) : null,
              child: const Text('Revisar arquivo'),
            ),
    );
  }
}

final class _ImportSummaryRow extends StatelessWidget {
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
