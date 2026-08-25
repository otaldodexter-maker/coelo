import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/activity/superadmin_activity.dart';
import '../../../../app/shell/superadmin_notice.dart';
import '../../../../core/platform/open_download.dart';
import '../../domain/unit_backend_commands.dart';
import '../../domain/unit_directory.dart';

final class UnitFileActions extends StatelessWidget {
  const UnitFileActions({
    required this.activityController,
    required this.query,
    required this.requestIdFactory,
    required this.groupByInstitution,
    this.backendCommands,
    this.compact = false,
    this.viewLabel,
    super.key,
  });

  final SuperadminActivityController activityController;
  final UnitDirectoryQuery query;
  final String Function() requestIdFactory;
  final bool groupByInstitution;
  final UnitBackendCommandsGateway? backendCommands;
  final bool compact;
  final String? viewLabel;

  Future<void> _export(BuildContext context, UnitFileFormat format) async {
    final gateway = backendCommands;
    if (gateway == null) {
      final demoFormat = format == UnitFileFormat.csv
          ? SuperadminExportFormat.csv
          : SuperadminExportFormat.xlsx;
      activityController.completeDemoExport(
        demoFormat,
        subject: viewLabel == null ? 'Unidades' : 'Unidades · $viewLabel',
        fileBaseName: viewLabel == null ? 'unidades' : 'unidades-${_viewSuffix(viewLabel!)}',
      );
      showSuperadminNotice(
        context,
        'A exportação está em andamento. Acompanhe pelo sininho.',
        icon: Icons.download_outlined,
      );
      return;
    }

    try {
      final result = await gateway.generateExport(
        UnitExportRequest(
          format: format,
          filters: UnitExportFilters(
            search: query.search,
            institutionIds: query.institutionIds,
            institutionTypeIds: query.institutionTypeIds,
            unitTypeIds: query.unitTypeIds,
            statuses: query.statuses,
            planIds: query.planIds,
            states: query.states,
            cities: query.cities,
            districts: query.districts,
          ),
          currentView: UnitExportCurrentView(
            sort: _exportSort(query.sortColumn),
            sortAscending: query.sortAscending,
            groupByInstitution: groupByInstitution,
            columns: const [
              'institution_name',
              'institution_type_name',
              'name',
              'unit_type_name',
              'unit_status',
              'effective_plan_name',
            ],
          ),
          idempotencyKey: requestIdFactory(),
        ),
      );
      if (!context.mounted) return;
      final opened = await openDownloadUrl(result.url.toString());
      if (!context.mounted) return;
      showSuperadminNotice(
        context,
        opened
            ? 'Exportação pronta. O download foi aberto em uma nova aba.'
            : 'Exportação pronta, mas o navegador bloqueou a abertura do download.',
        icon: opened ? Icons.download_done_outlined : Icons.info_outline,
      );
    } on UnitGatewayException {
      if (!context.mounted) return;
      showSuperadminNotice(
        context,
        'Não foi possível gerar a exportação autorizada. Tente novamente.',
        icon: Icons.error_outline,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CoeloAdminFileActions(
      compact: compact,
      actions: [
        CoeloAdminFileAction(
          key: const Key('unit-files-import'),
          label: 'Importar',
          icon: Icons.upload_file_outlined,
          onPressed: () =>
              _showImportDialog(context, activityController, backendCommands, requestIdFactory),
        ),
        CoeloAdminFileAction(
          key: const Key('unit-files-export-csv'),
          label: 'Exportar CSV',
          icon: Icons.table_rows_outlined,
          onPressed: () => _export(context, UnitFileFormat.csv),
        ),
        CoeloAdminFileAction(
          key: const Key('unit-files-export-xlsx'),
          label: 'Exportar XLSX',
          icon: Icons.grid_on_outlined,
          onPressed: () => _export(context, UnitFileFormat.xlsx),
        ),
      ],
    );
  }
}

UnitExportSortField _exportSort(UnitDirectorySortColumn value) => switch (value) {
  UnitDirectorySortColumn.name => UnitExportSortField.name,
  UnitDirectorySortColumn.institutionName => UnitExportSortField.institutionName,
  UnitDirectorySortColumn.institutionTypeName => UnitExportSortField.institutionType,
  UnitDirectorySortColumn.typeName => UnitExportSortField.unitType,
  UnitDirectorySortColumn.status => UnitExportSortField.status,
  UnitDirectorySortColumn.planName => UnitExportSortField.plan,
  UnitDirectorySortColumn.groupsCount => UnitExportSortField.groups,
  UnitDirectorySortColumn.activitiesCount => UnitExportSortField.activities,
  _ => UnitExportSortField.name,
};

String _viewSuffix(String label) => switch (label) {
  'Cards' => 'cards',
  'Agrupado' => 'agrupado',
  'Por turmas' => 'por-turmas',
  'Por atividades' => 'por-atividades',
  _ => 'visao',
};

Future<void> _showImportDialog(
  BuildContext context,
  SuperadminActivityController controller,
  UnitBackendCommandsGateway? backendCommands,
  String Function() requestIdFactory,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .54),
    builder: (dialogContext) => _UnitImportDialog(
      activityController: controller,
      noticeContext: context,
      backendCommands: backendCommands,
      requestIdFactory: requestIdFactory,
    ),
  );
}

final class _UnitImportDialog extends StatefulWidget {
  const _UnitImportDialog({
    required this.activityController,
    required this.noticeContext,
    required this.backendCommands,
    required this.requestIdFactory,
  });

  final SuperadminActivityController activityController;
  final BuildContext noticeContext;
  final UnitBackendCommandsGateway? backendCommands;
  final String Function() requestIdFactory;

  @override
  State<_UnitImportDialog> createState() => _UnitImportDialogState();
}

final class _UnitImportDialogState extends State<_UnitImportDialog> {
  PlatformFile? _file;
  UnitFileJob? _preview;
  bool _busy = false;

  Future<void> _pickFile() async {
    final noticeContext = widget.noticeContext;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
      allowMultiple: false,
    );
    if (!mounted || !noticeContext.mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) {
      showSuperadminNotice(
        noticeContext,
        'Não foi possível ler o arquivo selecionado.',
        icon: Icons.error_outline,
      );
      return;
    }
    setState(() {
      _file = file;
      _preview = null;
    });
  }

  Future<void> _review() async {
    final file = _file;
    final gateway = widget.backendCommands;
    if (file == null) return;
    if (gateway == null) {
      setState(() {
        _preview = UnitFileJob(
          id: 'preview',
          institutionId: '',
          domain: 'units',
          format: file.extension == 'csv' ? UnitFileFormat.csv : UnitFileFormat.xlsx,
          status: UnitFileJobStatus.draft,
          summary: const {'valid_count': 24, 'rejected_count': 2},
          createdAt: DateTime.now(),
          result: const UnitFileJobResult(),
          errors: const [],
        );
      });
      return;
    }

    setState(() => _busy = true);
    try {
      final format = file.extension?.toLowerCase() == 'csv'
          ? UnitFileFormat.csv
          : UnitFileFormat.xlsx;
      final job = await gateway.uploadImportPreview(
        requestId: widget.requestIdFactory(),
        fileName: file.name,
        mimeType: format.mimeType,
        bytes: file.bytes!,
      );
      if (!mounted || !widget.noticeContext.mounted) return;
      setState(() => _preview = job);
    } on UnitGatewayException {
      if (!mounted || !widget.noticeContext.mounted) return;
      showSuperadminNotice(
        widget.noticeContext,
        'O arquivo foi rejeitado. Revise formato, cabeçalhos e permissões.',
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startImport() async {
    final preview = _preview;
    if (preview == null) return;
    final gateway = widget.backendCommands;
    if (gateway == null) {
      widget.activityController.startDemoImport(
        subject: 'Unidades',
        fileName: _file?.name ?? 'unidades.xlsx',
        progressSummary: 'Importando unidades',
        completedSummary: '24 importadas, 2 rejeitadas',
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await gateway.confirmImport(
        UnitImportConfirmRequest(requestId: widget.requestIdFactory(), importJobId: preview.id),
      );
      if (!mounted || !widget.noticeContext.mounted) return;
      Navigator.of(context).pop();
      showSuperadminNotice(
        widget.noticeContext,
        result.result.rejectedCount == 0
            ? '${result.result.createdCount} unidades importadas.'
            : '${result.result.createdCount} importadas e ${result.result.rejectedCount} rejeitadas.',
        icon: result.result.rejectedCount == 0
            ? Icons.check_circle_outline
            : Icons.warning_amber_outlined,
      );
    } on UnitGatewayException {
      if (!mounted || !widget.noticeContext.mounted) return;
      showSuperadminNotice(
        widget.noticeContext,
        'Não foi possível confirmar a importação. O job pode ser retomado com segurança.',
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadTemplate() async {
    final gateway = widget.backendCommands;
    if (gateway == null) {
      showSuperadminNotice(
        widget.noticeContext,
        'Modelo XLSX preparado para download.',
        icon: Icons.file_download_outlined,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final artifact = await gateway.downloadImportTemplate(UnitFileFormat.xlsx);
      final uri = Uri.dataFromBytes(
        artifact.bytes,
        mimeType: artifact.mimeType,
        parameters: {'name': artifact.fileName},
      );
      await openDownloadUrl(uri.toString());
      if (!mounted || !widget.noticeContext.mounted) return;
      showSuperadminNotice(
        widget.noticeContext,
        'Modelo de unidades aberto para download.',
        icon: Icons.file_download_outlined,
      );
    } on UnitGatewayException {
      if (!mounted || !widget.noticeContext.mounted) return;
      showSuperadminNotice(
        widget.noticeContext,
        'Não foi possível gerar o modelo autorizado.',
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final preview = _preview;
    final valid = preview?.summary['valid_count'] ?? 0;
    final rejected = preview?.summary['rejected_count'] ?? preview?.errors.length ?? 0;
    return CoeloAdminDialogShell(
      dialogKey: const Key('unit-import-dialog'),
      closeButtonKey: const Key('unit-import-close'),
      closeTooltip: 'Fechar importação',
      title: 'Importar unidades',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            preview == null ? 'Etapa 1 de 2 · Arquivo' : 'Etapa 2 de 2 · Revisar',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.primary),
          ),
          const SizedBox(height: CoeloSpacing.space5),
          if (preview == null) ...[
            Text(
              'Use o modelo CSV ou XLSX. O servidor valida conteúdo, escopo e vínculos antes da confirmação.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: CoeloSpacing.space4),
            OutlinedButton.icon(
              key: const Key('unit-demo-file-picker'),
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.file_open_outlined),
              label: Text(_file?.name ?? 'Selecionar arquivo'),
            ),
          ] else ...[
            _SummaryRow(
              icon: Icons.check_circle_outline,
              label: '$valid linhas válidas',
              color: colors.primary,
            ),
            const SizedBox(height: CoeloSpacing.space2),
            _SummaryRow(
              icon: Icons.error_outline,
              label: '$rejected linhas com erro',
              color: colors.error,
            ),
            const SizedBox(height: CoeloSpacing.space3),
            Text(
              'Linhas rejeitadas não serão persistidas. O relatório permanece vinculado ao job auditado.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
      primaryAction: FilledButton(
        key: preview == null ? const Key('unit-import-review') : const Key('unit-import-confirm'),
        onPressed: _busy
            ? null
            : preview == null
            ? (_file == null ? null : _review)
            : _startImport,
        child: Text(preview == null ? 'Revisar arquivo' : 'Confirmar importação'),
      ),
      secondaryAction: OutlinedButton(
        key: preview == null
            ? const Key('unit-import-template-export')
            : const Key('unit-import-back'),
        onPressed: _busy
            ? null
            : preview == null
            ? _downloadTemplate
            : () => setState(() => _preview = null),
        child: Text(preview == null ? 'Exportar modelo .xlsx' : 'Voltar'),
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
