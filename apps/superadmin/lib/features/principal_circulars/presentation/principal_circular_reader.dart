import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../domain/circular.dart';
import '../domain/circular_repository.dart';

final class PrincipalCircularReader extends StatefulWidget {
  const PrincipalCircularReader({
    required this.detail,
    required this.onSubmit,
    this.initialAnswers = const {},
    super.key,
  });

  final CircularDetail detail;
  final Map<String, List<String>> initialAnswers;
  final Future<void> Function(Map<String, List<String>> answers) onSubmit;

  @override
  State<PrincipalCircularReader> createState() => _PrincipalCircularReaderState();
}

final class _PrincipalCircularReaderState extends State<PrincipalCircularReader> {
  late final Map<String, Set<String>> _answers = {
    for (final entry in widget.initialAnswers.entries) entry.key: {...entry.value},
  };
  var _submitting = false;
  var _submitted = false;
  String? _error;

  Iterable<CircularQuestionBlock> get _questions =>
      widget.detail.blocks.whereType<CircularQuestionBlock>();

  bool get _closed =>
      widget.detail.status == CircularStatus.closed ||
      (widget.detail.responsesCloseAt?.isBefore(DateTime.now()) ?? false);

  void _toggle(CircularQuestionBlock question, String optionId) {
    if (_closed || _submitting) return;
    setState(() {
      _error = null;
      final selected = _answers.putIfAbsent(question.id, () => <String>{});
      if (question.kind == CircularQuestionKind.singleChoice) {
        selected
          ..clear()
          ..add(optionId);
      } else if (!selected.add(optionId)) {
        selected.remove(optionId);
      }
      _submitted = false;
    });
  }

  Future<void> _submit() async {
    final missingRequired = _questions.any(
      (question) => question.required && (_answers[question.id]?.isEmpty ?? true),
    );
    if (missingRequired) {
      setState(() => _error = 'Responda às perguntas obrigatórias.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit({
        for (final entry in _answers.entries) entry.key: List.unmodifiable(entry.value),
      });
      if (!mounted) return;
      setState(() => _submitted = true);
    } on Object {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível enviar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      return SizedBox.expand(
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                compact ? CoeloSpacing.space4 : CoeloSpacing.space6,
                CoeloSpacing.space6,
                compact ? CoeloSpacing.space4 : CoeloSpacing.space6,
                CoeloSpacing.space10,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CircularHeader(detail: widget.detail),
                      const SizedBox(height: CoeloSpacing.space6),
                      for (final block in widget.detail.blocks) ...[
                        _block(block),
                        const SizedBox(height: CoeloSpacing.space5),
                      ],
                      if (_questions.isNotEmpty) ...[
                        if (_closed)
                          const _CircularFeedback(
                            icon: Icons.lock_clock_outlined,
                            message: 'Esta Circular está encerrada para respostas.',
                          )
                        else if (_submitted)
                          const _CircularFeedback(
                            icon: Icons.check_circle_outline_rounded,
                            message: 'Respostas enviadas',
                          ),
                        if (_error case final error?) ...[
                          const SizedBox(height: CoeloSpacing.space3),
                          _CircularFeedback(
                            icon: Icons.error_outline_rounded,
                            message: error,
                            error: true,
                          ),
                        ],
                        const SizedBox(height: CoeloSpacing.space4),
                        SizedBox(
                          height: CoeloSize.touchMin,
                          child: FilledButton.icon(
                            key: const Key('circular-submit-responses'),
                            onPressed: _closed || _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(_submitted ? 'Atualizar respostas' : 'Enviar respostas'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _block(CircularBlock block) => switch (block) {
    CircularTextBlock() => SelectableText(
      block.text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
    ),
    CircularMediaBlock() => _AttachmentGrid(assetIds: block.assetIds),
    CircularQuestionBlock() => _QuestionCard(
      question: block,
      selected: _answers[block.id] ?? const {},
      enabled: !_closed && !_submitting,
      onToggle: (optionId) => _toggle(block, optionId),
    ),
  };
}

final class _CircularHeader extends StatelessWidget {
  const _CircularHeader({required this.detail});
  final CircularDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = detail.publishedAt.toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: CoeloSpacing.space2),
            Text(
              'CIRCULAR',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space3),
        Text(
          detail.title,
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        Text(
          '${detail.authorName} · ${detail.contextLabel}',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: CoeloSpacing.space1),
        Text(
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
          '${detail.revisedAt == null ? '' : ' · Atualizada'}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

final class _AttachmentGrid extends StatelessWidget {
  const _AttachmentGrid({required this.assetIds});
  final List<String> assetIds;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final itemWidth = constraints.maxWidth < 520
          ? constraints.maxWidth
          : (constraints.maxWidth - CoeloSpacing.space3) / 2;
      return Wrap(
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space3,
        children: [
          for (var index = 0; index < assetIds.length; index++)
            SizedBox(
              width: itemWidth,
              child: _AttachmentTile(index: index),
            ),
        ],
      );
    },
  );
}

final class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Anexo ${index + 1}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
        ),
        child: Center(
          child: Icon(Icons.insert_drive_file_outlined, size: 36, color: colors.primary),
        ),
      ),
    );
  }
}

final class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });
  final CircularQuestionBlock question;
  final Set<String> selected;
  final bool enabled;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${question.prompt}${question.required ? ' *' : ''}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Text(
            question.kind == CircularQuestionKind.singleChoice
                ? 'Escolha uma opção'
                : 'Escolha uma ou mais opções',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: CoeloSpacing.space2),
          for (final option in question.options)
            _ChoiceOption(
              key: Key('circular-option-${question.id}-${option.id}'),
              option: option,
              multiple: question.kind == CircularQuestionKind.multipleChoice,
              selected: selected.contains(option.id),
              enabled: enabled,
              onPressed: () => onToggle(option.id),
            ),
        ],
      ),
    );
  }
}

final class _ChoiceOption extends StatefulWidget {
  const _ChoiceOption({
    required this.option,
    required this.multiple,
    required this.selected,
    required this.enabled,
    required this.onPressed,
    super.key,
  });
  final CircularQuestionOption option;
  final bool multiple;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_ChoiceOption> createState() => _ChoiceOptionState();
}

final class _ChoiceOptionState extends State<_ChoiceOption> {
  var _focused = false;
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final emphasized = widget.selected || _focused || _hovered;
    return FocusableActionDetector(
      enabled: widget.enabled,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed()),
      },
      child: Semantics(
        button: true,
        checked: widget.selected,
        enabled: widget.enabled,
        label: widget.option.label,
        child: TextButton(
          onPressed: widget.enabled ? widget.onPressed : null,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: colors.onSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space2),
            decoration: BoxDecoration(
              border: Border.all(
                color: emphasized ? colors.primary : Colors.transparent,
                width: _focused ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(CoeloRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  widget.multiple
                      ? (widget.selected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded)
                      : (widget.selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded),
                  color: widget.selected ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: CoeloSpacing.space2),
                Expanded(child: Text(widget.option.label)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _CircularFeedback extends StatelessWidget {
  const _CircularFeedback({required this.icon, required this.message, this.error = false});
  final IconData icon;
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = error ? colors.error : colors.primary;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        decoration: BoxDecoration(
          color: error ? colors.errorContainer : colors.primaryContainer,
          borderRadius: BorderRadius.circular(CoeloRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: CoeloSpacing.space2),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
