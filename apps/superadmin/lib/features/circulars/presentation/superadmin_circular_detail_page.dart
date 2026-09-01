import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../principal_circulars/domain/circular.dart';
import '../../principal_circulars/domain/circular_repository.dart';

final class SuperadminCircularDetailPage extends StatefulWidget {
  const SuperadminCircularDetailPage({
    required this.circularId,
    required this.repository,
    required this.onBack,
    this.onEdit,
    super.key,
  });

  final String circularId;
  final CircularRepository repository;
  final VoidCallback onBack;
  final VoidCallback? onEdit;

  @override
  State<SuperadminCircularDetailPage> createState() => _SuperadminCircularDetailPageState();
}

final class _SuperadminCircularDetailPageState extends State<SuperadminCircularDetailPage> {
  CircularDetail? _detail;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _detail = null;
      _error = null;
    });
    try {
      final detail = await widget.repository.getVisible(widget.circularId);
      if (mounted) setState(() => _detail = detail);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
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
                      if (widget.onEdit != null)
                        FilledButton.icon(
                          key: const Key('circular-detail-edit'),
                          onPressed: widget.onEdit,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar circular'),
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
