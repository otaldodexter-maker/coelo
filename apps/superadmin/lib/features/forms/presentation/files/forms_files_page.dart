import 'dart:async';
import 'dart:math';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

final class FormsFilesPage extends StatefulWidget {
  const FormsFilesPage({
    required this.api,
    required this.formId,
    required this.managementVersion,
    this.onDownload,
    super.key,
  });

  final FormsApi? api;
  final String formId;
  final int managementVersion;
  final ValueChanged<String>? onDownload;

  @override
  State<FormsFilesPage> createState() => _FormsFilesPageState();
}

final class _FormsFilesPageState extends State<FormsFilesPage> {
  FormCursorPage<FormFileJob>? _page;
  FormApiException? _failure;
  var _requesting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final api = widget.api;
    if (api == null) {
      setState(
        () => _failure = const FormApiException(
          FormApiFailureKind.unavailable,
          'O serviço de arquivos não está disponível.',
        ),
      );
      return;
    }
    try {
      final page = await api.listFileJobs(formId: widget.formId);
      if (mounted) {
        setState(() {
          _page = page;
          _failure = null;
        });
      }
    } on FormApiException catch (error) {
      if (mounted) setState(() => _failure = error);
    }
  }

  Future<void> _request(FormExportKind kind) async {
    final api = widget.api!;
    setState(() => _requesting = true);
    try {
      await api.requestExport(
        FormCommand(
          requestId: _uuid(),
          expectedVersion: widget.managementVersion,
          payload: FormExportPayload(formId: widget.formId, kind: kind),
        ),
      );
      await _load();
    } on FormApiException catch (error) {
      if (mounted) setState(() => _failure = error);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    if (failure != null) {
      return CoeloStatePanel(
        title: failure.kind == FormApiFailureKind.unauthorized
            ? 'Acesso não autorizado'
            : 'Arquivos indisponíveis',
        message: failure.message,
        icon: Icons.error_outline_rounded,
        actionLabel: failure.kind == FormApiFailureKind.unauthorized ? null : 'Tentar novamente',
        onAction: failure.kind == FormApiFailureKind.unauthorized ? null : _load,
      );
    }
    final page = _page;
    if (page == null) {
      return const CoeloStatePanel(
        title: 'Carregando arquivos',
        message: 'Aguarde enquanto os jobs autorizados são carregados.',
        loading: true,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      children: [
        Text('Arquivos e exportações', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: CoeloSpacing.space4),
        Wrap(
          spacing: CoeloSpacing.space3,
          runSpacing: CoeloSpacing.space3,
          children: [
            OutlinedButton.icon(
              onPressed: _requesting ? null : () => _request(FormExportKind.csv),
              icon: const Icon(Icons.table_rows_outlined),
              label: const Text('CSV'),
            ),
            OutlinedButton.icon(
              onPressed: _requesting ? null : () => _request(FormExportKind.xlsx),
              icon: const Icon(Icons.grid_on_outlined),
              label: const Text('XLSX'),
            ),
            FilledButton.icon(
              onPressed: _requesting ? null : () => _request(FormExportKind.zip),
              icon: const Icon(Icons.folder_zip_outlined),
              label: const Text('ZIP + mídias'),
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space5),
        if (page.items.isEmpty)
          const CoeloStatePanel(
            title: 'Nenhuma exportação solicitada',
            message: 'Escolha um formato para preparar um arquivo privado.',
            icon: Icons.file_download_outlined,
          )
        else
          for (final job in page.items)
            Card(
              child: ListTile(
                leading: Icon(_icon(job.status)),
                title: Text(_status(job)),
                subtitle: job.errorCode == null ? null : Text('Código: ${job.errorCode}'),
                trailing: job.downloadPath == null
                    ? null
                    : TextButton(
                        onPressed: () => widget.onDownload?.call(job.downloadPath!),
                        child: const Text('Baixar'),
                      ),
              ),
            ),
      ],
    );
  }

  String _status(FormFileJob job) => switch (job.status) {
    FormFileJobStatus.pending => 'Pendente',
    FormFileJobStatus.processing => 'Processando · ${(job.progress * 100).round()}%',
    FormFileJobStatus.succeeded => 'Concluído',
    FormFileJobStatus.partial => 'Concluído parcialmente',
    FormFileJobStatus.failed => 'Falhou',
    FormFileJobStatus.expired => 'Expirado',
  };

  IconData _icon(FormFileJobStatus status) => switch (status) {
    FormFileJobStatus.pending => Icons.schedule_outlined,
    FormFileJobStatus.processing => Icons.sync_rounded,
    FormFileJobStatus.succeeded => Icons.check_circle_outline_rounded,
    FormFileJobStatus.partial => Icons.warning_amber_rounded,
    FormFileJobStatus.failed => Icons.error_outline_rounded,
    FormFileJobStatus.expired => Icons.timer_off_outlined,
  };
}
