import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../principal_circulars/domain/circular.dart';
import '../../principal_circulars/domain/circular_repository.dart';
import '../domain/superadmin_circular_repository.dart';

typedef CircularDetailAction = Future<void> Function(CircularDetail detail);

final class SuperadminCircularDetailPage extends StatefulWidget {
  const SuperadminCircularDetailPage({
    required this.circularId,
    required this.repository,
    required this.onBack,
    this.onEdit,
    this.onCloseResponses,
    this.onDelete,
    this.onDeleted,
    this.responseSummarySource,
    super.key,
  });

  final String circularId;
  final CircularRepository repository;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final CircularDetailAction? onCloseResponses;
  final CircularDetailAction? onDelete;
  final VoidCallback? onDeleted;

  /// Fonte do resumo de respostas, quando a composicao a fornece.
  ///
  /// O leitor administrativo declara conteudo, contexto E resumo de respostas.
  /// O resumo e opcional de proposito: sem fonte, o leitor nao inventa numero
  /// nenhum e simplesmente nao mostra o bloco.
  final SuperadminCircularRepository? responseSummarySource;

  @override
  State<SuperadminCircularDetailPage> createState() => _SuperadminCircularDetailPageState();
}

final class _SuperadminCircularDetailPageState extends State<SuperadminCircularDetailPage> {
  CircularDetail? _detail;
  SuperadminCircularResponseSummary? _summary;
  Object? _error;
  var _loadGeneration = 0;
  var _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SuperadminCircularDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.circularId != widget.circularId ||
        !identical(oldWidget.repository, widget.repository)) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _detail = null;
      _summary = null;
      _error = null;
    });
    try {
      final detail = await widget.repository.getVisible(widget.circularId);
      if (mounted && generation == _loadGeneration) setState(() => _detail = detail);
    } on Object catch (error) {
      if (mounted && generation == _loadGeneration) setState(() => _error = error);
      return;
    }
    // O resumo e complementar: uma falha nele nao pode derrubar a leitura da
    // Circular, entao a ausencia simplesmente esconde o bloco.
    final source = widget.responseSummarySource;
    if (source == null) return;
    try {
      final summary = await source.fetchResponseSummary(widget.circularId);
      if (mounted && generation == _loadGeneration) setState(() => _summary = summary);
    } on Object {
      if (mounted && generation == _loadGeneration) setState(() => _summary = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error case final error?) {
      final forbidden = error is CircularUnauthorized || error is CircularNotAvailable;
      return CoeloStatePanel(
        title: forbidden ? 'Circular indisponível' : 'Não foi possível carregar',
        message: forbidden
            ? 'A Circular não está disponível neste contexto.'
            : 'Tente novamente em instantes.',
        icon: forbidden ? Icons.lock_outline_rounded : Icons.cloud_off_outlined,
        actionLabel: forbidden ? null : 'Tentar novamente',
        onAction: forbidden ? null : _load,
      );
    }
    final detail = _detail;
    if (detail == null) {
      return const CoeloStatePanel(
        title: 'Carregando Circular',
        message: 'Aguarde enquanto os dados são carregados.',
        loading: true,
      );
    }
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): widget.onBack},
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
            final content = _content(detail);
            return ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: ListView(
                padding: EdgeInsets.all(compact ? CoeloSpacing.space4 : CoeloSpacing.space6),
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: const Key('circular-detail-back'),
                        tooltip: 'Voltar para Circulares',
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: CoeloSpacing.space2),
                      Expanded(
                        child: Text(
                          'Detalhe da circular',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Wrap(
                        spacing: CoeloSpacing.space2,
                        runSpacing: CoeloSpacing.space2,
                        children: [
                          if (widget.onDelete != null && detail.status == CircularStatus.draft)
                            OutlinedButton.icon(
                              key: const Key('circular-detail-delete'),
                              onPressed: _actionBusy ? null : () => _confirmDelete(detail),
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Excluir'),
                            ),
                          if (widget.onCloseResponses != null &&
                              (detail.status == CircularStatus.published ||
                                  detail.status == CircularStatus.scheduled) &&
                              !(_summary?.closed ?? false))
                            OutlinedButton.icon(
                              key: const Key('circular-detail-close'),
                              onPressed: _actionBusy ? null : () => _confirmClose(detail),
                              icon: const Icon(Icons.lock_outline_rounded),
                              label: const Text('Encerrar respostas'),
                            ),
                          // O servidor recusa editar Circular encerrada ou arquivada
                          // (superadmin_circular_save_draft_v2): o botao so aparece
                          // quando a edicao e possivel.
                          if (widget.onEdit != null &&
                              detail.status != CircularStatus.closed &&
                              detail.status != CircularStatus.archived)
                            FilledButton.icon(
                              key: const Key('circular-detail-edit'),
                              onPressed: _actionBusy ? null : widget.onEdit,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Editar circular'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: CoeloSpacing.space6),
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: content,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _content(CircularDetail detail) {
    final colors = Theme.of(context).colorScheme;
    final body = detail.blocks.whereType<CircularTextBlock>().firstOrNull?.text ?? '';
    final mediaCount =
        detail.blocks.whereType<CircularMediaBlock>().firstOrNull?.assetIds.length ?? 0;
    final questions = detail.blocks.whereType<CircularQuestionBlock>().toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space6),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: CoeloSpacing.space2,
            runSpacing: CoeloSpacing.space2,
            children: [
              CoeloStatusChip(
                label: _statusLabel(detail.status),
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
              ),
              Text('${detail.authorName} · ${detail.contextLabel}'),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space4),
          Text(
            detail.title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Text(
            _date(detail.publishedAt),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: CoeloSpacing.space5),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: CoeloSpacing.space5),
          Divider(color: colors.outlineVariant),
          const SizedBox(height: CoeloSpacing.space3),
          Text('$mediaCount arquivos · ${questions.length} perguntas'),
          if (_summary case final summary?) ...[
            const SizedBox(height: CoeloSpacing.space2),
            Text(
              key: const Key('circular-detail-response-summary'),
              summary.closed
                  ? 'Respostas encerradas · ${summary.submittedCount} enviadas · '
                        '${summary.partialCount} parciais · ${summary.responseCount} no total'
                  : '${summary.submittedCount} enviadas · ${summary.partialCount} parciais · '
                        '${summary.responseCount} no total',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          for (final question in questions) ...[
            const SizedBox(height: CoeloSpacing.space3),
            Container(
              padding: const EdgeInsets.all(CoeloSpacing.space3),
              decoration: BoxDecoration(
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(CoeloRadius.md),
              ),
              child: Text(question.prompt),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmClose(CircularDetail detail) async {
    final confirmed = await _confirm(
      title: 'Encerrar respostas?',
      message: 'Novas respostas deixarão de ser aceitas para esta Circular.',
      confirmLabel: 'Encerrar respostas',
    );
    if (!confirmed || !mounted) return;
    await _runAction(detail, widget.onCloseResponses!, successMessage: 'Respostas encerradas.');
  }

  Future<void> _confirmDelete(CircularDetail detail) async {
    final confirmed = await _confirm(
      title: 'Excluir rascunho?',
      message: 'O rascunho será removido do diretório. Esta ação não pode ser desfeita.',
      confirmLabel: 'Excluir rascunho',
    );
    if (!confirmed || !mounted) return;
    await _runAction(detail, widget.onDelete!, onSuccess: widget.onDeleted);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('circular-detail-confirm-action'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _runAction(
    CircularDetail detail,
    CircularDetailAction action, {
    String? successMessage,
    VoidCallback? onSuccess,
  }) async {
    setState(() => _actionBusy = true);
    try {
      await action(detail);
      if (!mounted) return;
      if (onSuccess != null) {
        onSuccess();
      } else {
        await _load();
        if (mounted && successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
        }
      }
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível concluir esta ação. Tente novamente.')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }
}

String _statusLabel(CircularStatus status) => switch (status) {
  CircularStatus.draft => 'Rascunho',
  CircularStatus.scheduled => 'Agendada',
  CircularStatus.published => 'Publicada',
  CircularStatus.closed => 'Encerrada',
  CircularStatus.archived => 'Arquivada',
};

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String newCircularRequestId() {
  final random = math.Random.secure();
  String part(int length) =>
      List.generate(length, (_) => random.nextInt(16).toRadixString(16)).join();
  return '${part(8)}-${part(4)}-4${part(3)}-a${part(3)}-${part(12)}';
}
