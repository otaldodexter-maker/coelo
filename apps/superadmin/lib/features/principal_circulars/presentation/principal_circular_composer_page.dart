import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../application/circular_composer_controller.dart';
import '../domain/circular.dart';

final class PrincipalCircularComposerPage extends StatefulWidget {
  const PrincipalCircularComposerPage({
    required this.controller,
    required this.onCancel,
    required this.onPickFiles,
    this.onPublished,
    this.onChooseSchedule,
    super.key,
  });

  final CircularComposerController controller;
  final VoidCallback onCancel;
  final Future<void> Function() onPickFiles;
  final VoidCallback? onPublished;
  final Future<DateTime?> Function()? onChooseSchedule;

  @override
  State<PrincipalCircularComposerPage> createState() => _PrincipalCircularComposerPageState();
}

final class _PrincipalCircularComposerPageState extends State<PrincipalCircularComposerPage> {
  var _showPreview = false;
  DateTime? _publishAt;

  Future<void> _save() async {
    try {
      await widget.controller.save();
    } on Object {
      // Controller exposes a typed, user-safe state below.
    }
  }

  Future<void> _publish() async {
    try {
      await widget.controller.publish(publishAt: _publishAt);
      widget.onPublished?.call();
    } on Object {
      // Controller exposes a typed, user-safe state below.
    }
  }

  Future<void> _chooseSchedule() async {
    final callback = widget.onChooseSchedule;
    if (callback == null) return;
    final selected = await callback();
    if (mounted && selected != null) setState(() => _publishAt = selected);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
        final twoPane = constraints.maxWidth >= 980;
        final editor = _CircularEditor(
          controller: widget.controller,
          onPickFiles: widget.onPickFiles,
          publishAt: _publishAt,
          onChooseSchedule: widget.onChooseSchedule == null ? null : _chooseSchedule,
        );
        final preview = _CircularPreview(draft: widget.controller.draft);
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: IconButton(
              tooltip: 'Cancelar',
              onPressed: widget.controller.busy ? null : widget.onCancel,
              icon: const Icon(Icons.close_rounded),
            ),
            title: const Text('Publicar circular'),
            actions: [
              if (!twoPane)
                TextButton.icon(
                  key: const Key('circular-toggle-preview'),
                  onPressed: () => setState(() => _showPreview = !_showPreview),
                  icon: Icon(_showPreview ? Icons.edit_outlined : Icons.visibility_outlined),
                  label: Text(_showPreview ? 'Editar' : 'Prévia'),
                ),
              const SizedBox(width: CoeloSpacing.space2),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: twoPane
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 3, child: editor),
                            VerticalDivider(
                              width: 1,
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                            Expanded(flex: 2, child: preview),
                          ],
                        )
                      : (_showPreview ? preview : editor),
                ),
                _ComposerFeedback(
                  state: widget.controller.state,
                  errorCode: widget.controller.errorCode,
                ),
                _ComposerFooter(
                  compact: compact,
                  busy: widget.controller.busy,
                  scheduled: _publishAt?.isAfter(DateTime.now()) ?? false,
                  onCancel: widget.onCancel,
                  onSave: _save,
                  onPublish: _publish,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

final class _CircularEditor extends StatelessWidget {
  const _CircularEditor({
    required this.controller,
    required this.onPickFiles,
    required this.publishAt,
    required this.onChooseSchedule,
  });
  final CircularComposerController controller;
  final Future<void> Function() onPickFiles;
  final DateTime? publishAt;
  final VoidCallback? onChooseSchedule;

  @override
  Widget build(BuildContext context) {
    final draft = controller.draft;
    final body = draft.blocks.whereType<CircularTextBlock>().firstOrNull?.text ?? '';
    final media = draft.blocks.whereType<CircularMediaBlock>().firstOrNull;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SyncedField(
                fieldKey: const Key('circular-title'),
                value: draft.title,
                label: 'Título da circular',
                hint: 'Renovação de matrícula para 2027',
                icon: Icons.title_rounded,
                maxLength: CircularLimits.titleCharacters,
                onChanged: controller.updateTitle,
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _SyncedField(
                fieldKey: const Key('circular-body'),
                value: body,
                label: 'Texto da circular',
                hint: 'Escreva a comunicação completa.',
                icon: Icons.notes_rounded,
                maxLength: CircularLimits.bodyCharacters,
                maxLines: 8,
                onChanged: controller.updateBody,
              ),
              const SizedBox(height: CoeloSpacing.space5),
              _SectionTitle(
                title: 'Arquivos e mídia',
                trailing: '${media?.assetIds.length ?? 0}/4',
              ),
              const SizedBox(height: CoeloSpacing.space2),
              OutlinedButton.icon(
                key: const Key('circular-pick-files'),
                onPressed: media != null && media.assetIds.length >= CircularLimits.files
                    ? null
                    : onPickFiles,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Adicionar foto, vídeo ou PDF'),
              ),
              if (media != null)
                for (final assetId in media.assetIds)
                  _MediaDraftRow(
                    assetId: assetId,
                    onRemove: () => controller.removeMediaAsset(assetId),
                  ),
              const SizedBox(height: CoeloSpacing.space5),
              _SectionTitle(
                title: 'Perguntas',
                trailing: '${draft.blocks.whereType<CircularQuestionBlock>().length}/10',
              ),
              const SizedBox(height: CoeloSpacing.space2),
              for (final question in draft.blocks.whereType<CircularQuestionBlock>()) ...[
                _QuestionEditor(controller: controller, question: question),
                const SizedBox(height: CoeloSpacing.space3),
              ],
              OutlinedButton.icon(
                key: const Key('circular-add-question'),
                onPressed:
                    draft.blocks.whereType<CircularQuestionBlock>().length >=
                        CircularLimits.questions
                    ? null
                    : () => controller.addQuestion(CircularQuestionKind.singleChoice),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar pergunta'),
              ),
              const SizedBox(height: CoeloSpacing.space5),
              _AudienceSelector(controller: controller),
              const SizedBox(height: CoeloSpacing.space3),
              _InfoPanel(
                icon: Icons.schedule_outlined,
                title: 'Agendamento',
                subtitle: publishAt == null ? 'Publicar agora' : 'Publicação futura selecionada',
                onTap: onChooseSchedule,
              ),
              const SizedBox(height: CoeloSpacing.space3),
              const _InfoPanel(
                icon: Icons.lock_outline_rounded,
                title: 'Privacidade',
                subtitle: 'Mídia privada e acesso limitado ao público autorizado',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _AudienceSelector extends StatelessWidget {
  const _AudienceSelector({required this.controller});

  final CircularComposerController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const labels = {
      CircularAudienceKind.families: 'Famílias e responsáveis',
      CircularAudienceKind.guardiansOnly: 'Somente responsáveis',
      CircularAudienceKind.students: 'Alunos',
      CircularAudienceKind.schoolStaff: 'Equipe autorizada',
    };
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
            'Público e contexto',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            'O contexto é validado pelo servidor. Selecione quem receberá a Circular.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          for (final entry in labels.entries)
            Semantics(
              checked: controller.draft.audiences.contains(entry.key),
              label: entry.value,
              child: TextButton(
                key: Key('circular-audience-${entry.key.name}'),
                onPressed: () => controller.toggleAudience(entry.key),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: colors.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CoeloRadius.md),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
                  child: Row(
                    children: [
                      Icon(
                        controller.draft.audiences.contains(entry.key)
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: controller.draft.audiences.contains(entry.key)
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: CoeloSpacing.space2),
                      Expanded(child: Text(entry.value)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _QuestionEditor extends StatelessWidget {
  const _QuestionEditor({required this.controller, required this.question});
  final CircularComposerController controller;
  final CircularQuestionBlock question;

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
          Row(
            children: [
              const Icon(Icons.drag_indicator_rounded),
              const SizedBox(width: CoeloSpacing.space1),
              Expanded(
                child: Text(
                  'Pergunta',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Mover para cima',
                onPressed: () => controller.moveQuestion(question.id, -1),
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                tooltip: 'Mover para baixo',
                onPressed: () => controller.moveQuestion(question.id, 1),
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
              IconButton(
                tooltip: 'Duplicar',
                onPressed: () => controller.duplicateQuestion(question.id),
                icon: const Icon(Icons.copy_outlined),
              ),
              IconButton(
                tooltip: 'Excluir',
                color: colors.error,
                onPressed: () => controller.removeQuestion(question.id),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space2),
          _SyncedField(
            value: question.prompt,
            label: 'Enunciado',
            icon: Icons.help_outline_rounded,
            maxLength: CircularLimits.questionCharacters,
            onChanged: (value) => controller.updateQuestion(question.id, prompt: value),
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Wrap(
            spacing: CoeloSpacing.space2,
            runSpacing: CoeloSpacing.space2,
            children: [
              OutlinedButton.icon(
                onPressed: () => controller.updateQuestion(
                  question.id,
                  kind: question.kind == CircularQuestionKind.singleChoice
                      ? CircularQuestionKind.multipleChoice
                      : CircularQuestionKind.singleChoice,
                ),
                icon: Icon(
                  question.kind == CircularQuestionKind.singleChoice
                      ? Icons.radio_button_checked_rounded
                      : Icons.check_box_rounded,
                ),
                label: Text(
                  question.kind == CircularQuestionKind.singleChoice
                      ? 'Escolha única'
                      : 'Múltipla escolha',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    controller.updateQuestion(question.id, required: !question.required),
                icon: Icon(
                  question.required
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                ),
                label: const Text('Obrigatória'),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space2),
          for (final option in question.options)
            Padding(
              padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SyncedField(
                      value: option.label,
                      label: 'Alternativa',
                      icon: Icons.circle_outlined,
                      maxLength: CircularLimits.optionCharacters,
                      onChanged: (value) => controller.updateOption(question.id, option.id, value),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remover alternativa',
                    color: colors.error,
                    onPressed: question.options.length <= CircularLimits.minimumOptions
                        ? null
                        : () => controller.removeOption(question.id, option.id),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: question.options.length >= CircularLimits.maximumOptions
                ? null
                : () => controller.addOption(question.id),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar alternativa'),
          ),
        ],
      ),
    );
  }
}

final class _CircularPreview extends StatelessWidget {
  const _CircularPreview({required this.draft});
  final CircularDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = draft.blocks.whereType<CircularTextBlock>().firstOrNull?.text ?? '';
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(CoeloRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description_outlined, color: theme.colorScheme.primary),
                      const SizedBox(width: CoeloSpacing.space2),
                      const Text('Circular'),
                    ],
                  ),
                  const SizedBox(height: CoeloSpacing.space3),
                  Text(
                    draft.title.isEmpty ? 'Título da circular' : draft.title,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: CoeloSpacing.space2),
                  Text(
                    body.isEmpty ? 'A prévia do conteúdo aparecerá aqui.' : body,
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                  for (final question in draft.blocks.whereType<CircularQuestionBlock>()) ...[
                    const SizedBox(height: CoeloSpacing.space3),
                    Text(
                      question.prompt,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    for (final option in question.options)
                      Padding(
                        padding: const EdgeInsets.only(top: CoeloSpacing.space1),
                        child: Row(
                          children: [
                            Icon(
                              question.kind == CircularQuestionKind.singleChoice
                                  ? Icons.radio_button_off_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: CoeloSpacing.space2),
                            Expanded(child: Text(option.label)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _SyncedField extends StatefulWidget {
  const _SyncedField({
    required this.value,
    required this.label,
    required this.icon,
    required this.onChanged,
    this.fieldKey,
    this.hint,
    this.maxLength,
    this.maxLines = 1,
  });
  final String value;
  final String label;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final Key? fieldKey;
  final String? hint;
  final int? maxLength;
  final int maxLines;
  @override
  State<_SyncedField> createState() => _SyncedFieldState();
}

final class _SyncedFieldState extends State<_SyncedField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(covariant _SyncedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoeloFormTextField(
    fieldKey: widget.fieldKey,
    controller: _controller,
    labelText: widget.label,
    hintText: widget.hint,
    prefixIcon: widget.icon,
    maxLength: widget.maxLength,
    maxLines: widget.maxLines,
    onChanged: widget.onChanged,
  );
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.trailing});
  final String title;
  final String trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      Text(trailing),
    ],
  );
}

final class _MediaDraftRow extends StatelessWidget {
  const _MediaDraftRow({required this.assetId, required this.onRemove});
  final String assetId;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: CoeloSize.touchMin,
    child: Row(
      children: [
        const Icon(Icons.insert_drive_file_outlined),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(child: Text('Arquivo ${assetId.substring(0, assetId.length.clamp(0, 8))}')),
        IconButton(
          tooltip: 'Remover arquivo',
          color: Theme.of(context).colorScheme.error,
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

final class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.icon, required this.title, required this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(CoeloRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: CoeloSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(subtitle),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

final class _ComposerFeedback extends StatelessWidget {
  const _ComposerFeedback({required this.state, required this.errorCode});
  final CircularComposerState state;
  final String? errorCode;
  @override
  Widget build(BuildContext context) {
    final message = switch (state) {
      CircularComposerState.saving => 'Salvando…',
      CircularComposerState.saved => 'Rascunho salvo',
      CircularComposerState.publishing => 'Publicando…',
      CircularComposerState.published => 'Circular publicada',
      CircularComposerState.conflict =>
        'A Circular foi alterada em outro lugar. Recarregue antes de continuar.',
      CircularComposerState.failure when errorCode == 'audienceRequired' =>
        'Selecione ao menos um público antes de publicar.',
      CircularComposerState.failure => 'Não foi possível concluir. Tente novamente.',
      CircularComposerState.editing => null,
    };
    return message == null
        ? const SizedBox.shrink()
        : Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CoeloSpacing.space4,
                vertical: CoeloSpacing.space2,
              ),
              child: Text(message, textAlign: TextAlign.center),
            ),
          );
  }
}

final class _ComposerFooter extends StatelessWidget {
  const _ComposerFooter({
    required this.compact,
    required this.busy,
    required this.scheduled,
    required this.onCancel,
    required this.onSave,
    required this.onPublish,
  });
  final bool compact;
  final bool busy;
  final bool scheduled;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onPublish;
  @override
  Widget build(BuildContext context) {
    final actions = [
      OutlinedButton(
        key: const Key('circular-save-draft'),
        onPressed: busy ? null : onSave,
        child: const Text('Salvar rascunho'),
      ),
      FilledButton(
        key: const Key('circular-publish'),
        onPressed: busy ? null : onPublish,
        child: Text(scheduled ? 'Agendar circular' : 'Publicar circular'),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: CoeloSize.touchMin, child: actions.last),
                const SizedBox(height: CoeloSpacing.space2),
                SizedBox(height: CoeloSize.touchMin, child: actions.first),
              ],
            )
          : Row(
              children: [
                TextButton(onPressed: busy ? null : onCancel, child: const Text('Cancelar')),
                const Spacer(),
                actions.first,
                const SizedBox(width: CoeloSpacing.space2),
                actions.last,
              ],
            ),
    );
  }
}
