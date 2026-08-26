import 'dart:convert';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/activity/superadmin_activity.dart';
import '../../../../app/shell/superadmin_notice.dart';
import '../../../../core/platform/open_download.dart';
import '../../domain/unit_backend_commands.dart';
import '../../domain/unit_directory.dart';

final class UnitFileActions extends StatefulWidget {
  const UnitFileActions({
    required this.activityController,
    required this.query,
    required this.requestIdFactory,
    required this.groupByInstitution,
    this.backendCommands,
    this.compact = false,
    this.viewLabel,
    this.openUrl,
    super.key,
  });

  final SuperadminActivityController activityController;
  final UnitDirectoryQuery query;
  final String Function() requestIdFactory;
  final bool groupByInstitution;
  final UnitBackendCommandsGateway? backendCommands;
  final bool compact;
  final String? viewLabel;
  final Future<bool> Function(String url)? openUrl;

  @override
  State<UnitFileActions> createState() => _UnitFileActionsState();
}

final class _UnitFileActionsState extends State<UnitFileActions> {
  bool _exportBusy = false;
  _UnitExportAttempt? _retryAttempt;
  _UnitPendingDownload? _pendingDownload;

  Future<void> _export(BuildContext context, UnitFileFormat format) async {
    if (_exportBusy) return;
    final gateway = widget.backendCommands;
    if (gateway == null) {
      final demoFormat = format == UnitFileFormat.csv
          ? SuperadminExportFormat.csv
          : SuperadminExportFormat.xlsx;
      widget.activityController.completeDemoExport(
        demoFormat,
        subject: widget.viewLabel == null ? 'Unidades' : 'Unidades · ${widget.viewLabel}',
        fileBaseName: widget.viewLabel == null
            ? 'unidades'
            : 'unidades-${_viewSuffix(widget.viewLabel!)}',
      );
      showSuperadminNotice(
        context,
        'A exportação está em andamento. Acompanhe pelo sininho.',
        icon: Icons.download_outlined,
      );
      return;
    }

    final signature = _exportSignature(format);
    setState(() => _exportBusy = true);
    try {
      var pending = _pendingDownload;
      if (pending != null && pending.signature != signature) {
        _pendingDownload = null;
        pending = null;
      }

      if (pending == null) {
        final retainedAttempt = _retryAttempt;
        final attempt = retainedAttempt != null && retainedAttempt.signature == signature
            ? retainedAttempt
            : _UnitExportAttempt(
                signature: signature,
                request: _buildExportRequest(format, widget.requestIdFactory()),
              );
        if (!identical(attempt, retainedAttempt)) _retryAttempt = attempt;

        final result = await gateway.generateExport(attempt.request);
        if (!mounted) return;
        _retryAttempt = null;
        if (!result.expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
          throw const UnitExportException(
            code: UnitExportFailureCode.expired,
            message: 'The signed export URL has expired.',
          );
        }
        pending = _UnitPendingDownload(signature: signature, download: result);
        _pendingDownload = pending;
      } else if (!pending.download.expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
        _pendingDownload = null;
        throw const UnitExportException(
          code: UnitExportFailureCode.expired,
          message: 'The signed export URL has expired.',
        );
      }

      final opened = await _openValidatedDownload(pending.download.url.toString());
      if (!context.mounted) return;
      if (opened) _pendingDownload = null;
      showSuperadminNotice(
        context,
        opened
            ? 'Exportação pronta. O download foi aberto em uma nova aba.'
            : 'Exportação pronta, mas o navegador bloqueou a abertura do download.',
        icon: opened ? Icons.download_done_outlined : Icons.info_outline,
      );
    } on UnitExportException catch (error) {
      if (!_retainsIdempotencyKey(error.code)) _retryAttempt = null;
      _pendingDownload = null;
      if (!context.mounted) return;
      showSuperadminNotice(context, _exportFailureNotice(error.code), icon: Icons.error_outline);
    } on UnitGatewayException catch (error) {
      if (!error.retriable) _retryAttempt = null;
      if (!context.mounted) return;
      showSuperadminNotice(context, _gatewayFailureNotice(error.code), icon: Icons.error_outline);
    } on ArgumentError {
      _retryAttempt = null;
      if (!context.mounted) return;
      showSuperadminNotice(
        context,
        'Não foi possível validar esta tentativa de exportação. Tente novamente.',
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Future<bool> _openValidatedDownload(String url) async {
    try {
      return await (widget.openUrl ?? openDownloadUrl)(url);
    } on Object {
      return false;
    }
  }

  UnitExportRequest _buildExportRequest(UnitFileFormat format, String idempotencyKey) =>
      UnitExportRequest(
        format: format,
        filters: _exportFilters,
        currentView: _exportCurrentView,
        idempotencyKey: idempotencyKey,
      );

  UnitExportFilters get _exportFilters => UnitExportFilters(
    search: widget.query.search,
    institutionIds: widget.query.institutionIds,
    institutionTypeIds: widget.query.institutionTypeIds,
    unitTypeIds: widget.query.unitTypeIds,
    statuses: widget.query.statuses,
    planIds: widget.query.planIds,
    states: widget.query.states,
    cities: widget.query.cities,
    districts: widget.query.districts,
  );

  UnitExportCurrentView get _exportCurrentView => UnitExportCurrentView(
    sort: _exportSort(widget.query.sortColumn),
    sortAscending: widget.query.sortAscending,
    groupByInstitution: widget.groupByInstitution,
    columns: const [
      'institution_name',
      'institution_type_name',
      'name',
      'unit_type_name',
      'unit_status',
      'effective_plan_name',
    ],
  );

  String _exportSignature(UnitFileFormat format) => jsonEncode({
    'format': format.databaseValue,
    'filters': _exportFilters.toRpc(),
    'current_view': _exportCurrentView.toRpc(),
  });

  @override
  Widget build(BuildContext context) {
    final actions = CoeloAdminFileActions(
      compact: widget.compact,
      actions: [
        CoeloAdminFileAction(
          key: const Key('unit-files-import'),
          label: 'Importar',
          icon: Icons.upload_file_outlined,
          onPressed: () => _showImportDialog(
            context,
            widget.activityController,
            widget.backendCommands,
            widget.requestIdFactory,
          ),
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
    return Semantics(
      key: const Key('unit-files-export-semantics'),
      container: true,
      liveRegion: _exportBusy,
      enabled: !_exportBusy,
      label: _exportBusy ? 'Exportação de unidades em andamento' : 'Ações de arquivos de unidades',
      child: ExcludeFocus(
        excluding: _exportBusy,
        child: AbsorbPointer(
          absorbing: _exportBusy,
          child: ExcludeSemantics(excluding: _exportBusy, child: actions),
        ),
      ),
    );
  }
}

final class _UnitExportAttempt {
  const _UnitExportAttempt({required this.signature, required this.request});

  final String signature;
  final UnitExportRequest request;
}

final class _UnitPendingDownload {
  const _UnitPendingDownload({required this.signature, required this.download});

  final String signature;
  final UnitExportDownload download;
}

String _exportFailureNotice(UnitExportFailureCode code) => switch (code) {
  UnitExportFailureCode.invalidDownloadUrl =>
    'O link de download recebido não é seguro. Gere uma nova exportação.',
  UnitExportFailureCode.expired => 'O link de download expirou. Gere uma nova exportação.',
  UnitExportFailureCode.notReady =>
    'A exportação ainda está sendo processada. Tente novamente em instantes.',
  UnitExportFailureCode.terminal =>
    'A exportação não pôde ser concluída. Revise os filtros e tente novamente.',
  UnitExportFailureCode.invalidResponse =>
    'A resposta da exportação não pôde ser validada. Tente novamente.',
};

bool _retainsIdempotencyKey(UnitExportFailureCode code) =>
    code == UnitExportFailureCode.notReady || code == UnitExportFailureCode.invalidResponse;

String _gatewayFailureNotice(UnitGatewayErrorCode code) => switch (code) {
  UnitGatewayErrorCode.unauthorized =>
    'Sua sessão não autoriza esta exportação. Entre novamente e tente de novo.',
  UnitGatewayErrorCode.notFound =>
    'A exportação solicitada não foi encontrada. Gere uma nova exportação.',
  UnitGatewayErrorCode.conflict => 'A exportação mudou enquanto era processada. Tente novamente.',
  UnitGatewayErrorCode.validation =>
    'Os filtros da exportação foram rejeitados. Revise-os e tente novamente.',
  UnitGatewayErrorCode.unavailable =>
    'Não foi possível gerar a exportação autorizada. Tente novamente.',
  UnitGatewayErrorCode.unexpected => 'Não foi possível concluir a exportação. Tente novamente.',
};

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
