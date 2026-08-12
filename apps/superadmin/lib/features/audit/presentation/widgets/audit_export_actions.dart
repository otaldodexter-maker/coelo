import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../domain/audit.dart';
import '../audit_controller.dart';

final class AuditExportActions extends StatelessWidget {
  const AuditExportActions({
    required this.controller,
    required this.compact,
    required this.openDownloadUrl,
    super.key,
  });

  final AuditDirectoryController controller;
  final bool compact;
  final Future<bool> Function(String url) openDownloadUrl;

  @override
  Widget build(BuildContext context) => CoeloAdminFileActions(
    compact: compact,
    actions: [
      CoeloAdminFileAction(
        label: 'Exportar CSV',
        icon: Icons.table_view_outlined,
        onPressed: () => _confirm(context, AuditExportFormat.csv),
      ),
      CoeloAdminFileAction(
        label: 'Exportar XLSX',
        icon: Icons.grid_on_outlined,
        onPressed: () => _confirm(context, AuditExportFormat.xlsx),
      ),
    ],
  );

  void _confirm(BuildContext context, AuditExportFormat format) {
    showDialog<void>(
      context: context,
      builder: (context) => _AuditExportDialog(
        controller: controller,
        format: format,
        openDownloadUrl: openDownloadUrl,
      ),
    );
  }
}

final class _AuditExportDialog extends StatefulWidget {
  const _AuditExportDialog({
    required this.controller,
    required this.format,
    required this.openDownloadUrl,
  });

  final AuditDirectoryController controller;
  final AuditExportFormat format;
  final Future<bool> Function(String url) openDownloadUrl;

  @override
  State<_AuditExportDialog> createState() => _AuditExportDialogState();
}

final class _AuditExportDialogState extends State<_AuditExportDialog> {
  AuditExportJob? _job;
  String? _message;
  var _busy = false;

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    title: 'Exportar auditoria',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'A exportação ${widget.format.name.toUpperCase()} respeitará os filtros e o escopo atuais.',
        ),
        if (_busy) ...[
          const SizedBox(height: CoeloSpacing.space4),
          const LinearProgressIndicator(),
          const SizedBox(height: CoeloSpacing.space2),
          const Text('Consultando o processamento protegido...'),
        ],
        if (_job case final job?) ...[
          const SizedBox(height: CoeloSpacing.space4),
          _ExportStatus(job: job),
        ],
        if (_message case final message?) ...[
          const SizedBox(height: CoeloSpacing.space3),
          Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    ),
    secondaryAction: OutlinedButton(
      onPressed: _busy ? null : () => Navigator.of(context).pop(),
      child: const Text('Fechar'),
    ),
    primaryAction: FilledButton(
      onPressed: _busy ? null : _primaryAction,
      child: Text(_primaryLabel),
    ),
  );

  String get _primaryLabel {
    final job = _job;
    if (job == null) return 'Solicitar exportação';
    if (job.status == AuditExportStatus.completed && job.downloadUrl != null) {
      return 'Baixar arquivo';
    }
    if (job.status == AuditExportStatus.failed) return 'Tentar novamente';
    return 'Atualizar status';
  }

  Future<void> _primaryAction() async {
    final job = _job;
    if (job?.status == AuditExportStatus.completed && job?.downloadUrl != null) {
      await _download(job!);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final next = job == null || job.status == AuditExportStatus.failed
          ? await widget.controller.startExport(format: widget.format)
          : await widget.controller.fetchExportStatus(job.id);
      if (!mounted) return;
      setState(() => _job = next);
    } on Exception {
      if (mounted) {
        setState(() => _message = 'Não foi possível processar a exportação. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(AuditExportJob job) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final refreshed = await widget.controller.fetchExportStatus(job.id);
      final url = refreshed.downloadUrl;
      if (!mounted) return;
      setState(() => _job = refreshed);
      if (refreshed.status != AuditExportStatus.completed || url == null || url.scheme != 'https') {
        setState(() => _message = 'O arquivo temporário não está disponível com segurança.');
        return;
      }
      final opened = await widget.openDownloadUrl(url.toString());
      if (!mounted || opened) return;
      setState(() => _message = 'Não foi possível abrir o download temporário.');
    } on Exception {
      if (mounted) {
        setState(() => _message = 'Não foi possível renovar o link temporário. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final class _ExportStatus extends StatelessWidget {
  const _ExportStatus({required this.job});

  final AuditExportJob job;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final failed = job.status == AuditExportStatus.failed;
    return Semantics(
      liveRegion: true,
      label: _statusLabel(job.status),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: failed ? colors.errorContainer : colors.surface,
          border: Border.all(color: failed ? colors.error : colors.outlineVariant),
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_statusLabel(job.status), style: Theme.of(context).textTheme.titleSmall),
              if (job.rowCount case final count?) Text('$count registros preparados'),
              if (job.retentionExpiresAt case final expiry?)
                Text('Arquivo disponível até ${_formatExpiry(expiry)}'),
              if (job.downloadExpiresInSeconds case final seconds?)
                Text('Link temporário válido por ${seconds ~/ 60} min'),
              if (job.errorCode != null) const Text('O processamento informou uma falha segura.'),
            ],
          ),
        ),
      ),
    );
  }
}

String _statusLabel(AuditExportStatus status) => switch (status) {
  AuditExportStatus.queued => 'Exportação enfileirada',
  AuditExportStatus.processing => 'Exportação em processamento',
  AuditExportStatus.completed => 'Exportação concluída',
  AuditExportStatus.failed => 'Exportação com falha',
};

String _formatExpiry(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}
