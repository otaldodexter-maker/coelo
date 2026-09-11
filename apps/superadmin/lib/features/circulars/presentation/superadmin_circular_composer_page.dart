import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/publication_surface.dart';
import '../../principal_circulars/application/circular_composer_controller.dart';
import '../../principal_circulars/domain/circular.dart';

/// Superadmin composition for the Circular domain. Domain state and persistence
/// remain owned by [CircularComposerController]; no Principal presentation
/// widget crosses the administrative package boundary.
final class SuperadminCircularComposerPage extends StatefulWidget {
  const SuperadminCircularComposerPage({
    required this.controller,
    required this.onCancel,
    required this.onPickFiles,
    this.onPublished,
    this.onChooseSchedule,
    this.contextLabel,
    super.key,
  });

  final CircularComposerController controller;

  /// Nome da instituição do contexto (linha de "Público e contexto" e prévia).
  final String? contextLabel;
  final VoidCallback onCancel;
  final Future<void> Function() onPickFiles;
  final VoidCallback? onPublished;
  final Future<DateTime?> Function()? onChooseSchedule;

  @override
  State<SuperadminCircularComposerPage> createState() => _SuperadminCircularComposerPageState();
}

final class _SuperadminCircularComposerPageState extends State<SuperadminCircularComposerPage> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  DateTime? _publishAt;
  int _contextGeneration = 0;
  int _scheduleGeneration = 0;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.controller.draft.title);
    _body = TextEditingController(text: _bodyText(widget.controller.draft));
  }

  @override
  void didUpdateWidget(covariant SuperadminCircularComposerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    _contextGeneration++;
    _scheduleGeneration++;
    _title.text = widget.controller.draft.title;
    _body.text = _bodyText(widget.controller.draft);
    _publishAt = null;
  }

  @override
  void dispose() {
    _contextGeneration++;
    _scheduleGeneration++;
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await widget.controller.save();
    } on Object {
      // The controller exposes a user-safe state in the page feedback.
    }
  }

  Future<void> _publish() async {
    final controller = widget.controller;
    final generation = _contextGeneration;
    final onPublished = widget.onPublished;
    try {
      await controller.publish(publishAt: _publishAt);
      if (!mounted ||
          generation != _contextGeneration ||
          !identical(controller, widget.controller)) {
        return;
      }
      onPublished?.call();
    } on Object {
      // The controller exposes a user-safe state in the page feedback.
    }
  }

  Future<void> _chooseSchedule() async {
    final choose = widget.onChooseSchedule;
    if (choose == null) return;
    final generation = _contextGeneration;
    final scheduleGeneration = ++_scheduleGeneration;
    final selected = await choose();
    if (mounted &&
        generation == _contextGeneration &&
        scheduleGeneration == _scheduleGeneration &&
        selected != null) {
      setState(() => _publishAt = selected);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => PublicationSurface(
      subtitle: widget.controller.draft.id.isEmpty ? 'Publicar Circular' : 'Editar Circular',
      scrollKey: const Key('superadmin-circular-editor'),
      footerKey: const Key('circular-publication-footer'),
      form: _form(),
      preview: _CircularAdminPreview(
        key: const Key('superadmin-circular-preview'),
        draft: widget.controller.draft,
        contextLabel: widget.contextLabel,
      ),
      feedback: _feedback(),
      tertiaryAction: TextButton(
        key: const Key('circular-cancel'),
        onPressed: widget.controller.busy ? null : widget.onCancel,
        child: const Text('Cancelar'),
      ),
      continuationActions: [
        OutlinedButton(
          key: const Key('circular-save-draft'),
          onPressed: widget.controller.busy ? null : _save,
          child: const Text('Salvar rascunho'),
        ),
        FilledButton(
          key: const Key('circular-publish'),
          onPressed: widget.controller.busy ? null : _publish,
          child: Text(
            _publishAt?.isAfter(DateTime.now()) ?? false ? 'Agendar circular' : 'Publicar circular',
          ),
        ),
      ],
    ),
  );

  Widget _form() {
    final controller = widget.controller;
    final draft = controller.draft;
    final media = draft.blocks.whereType<CircularMediaBlock>().firstOrNull;
    final questions = draft.blocks.whereType<CircularQuestionBlock>().toList(growable: false);
    final preset = _responsePreset(questions);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PublicationLabel('Título'),
        PublicationTextField(
          fieldKey: const Key('circular-title'),
          controller: _title,
          hintText: 'Reunião de pais e responsáveis — 3º ano',
          maxLength: CircularLimits.titleCharacters,
          onChanged: controller.updateTitle,
        ),
        const PublicationLabel('Texto da circular'),
        PublicationTextField(
          fieldKey: const Key('circular-body'),
          controller: _body,
          hintText: 'Escreva a comunicação completa.',
          maxLength: CircularLimits.bodyCharacters,
          maxLines: 6,
          onChanged: controller.updateBody,
        ),
        PublicationLabel('Anexos', hint: 'até ${CircularLimits.files} · PDF ou imagem'),
        Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: CoeloSize.touchMin,
              height: CoeloSize.touchMin,
              child: OutlinedButton(
                key: const Key('circular-pick-files'),
                onPressed: media != null && media.assetIds.length >= CircularLimits.files
                    ? null
                    : widget.onPickFiles,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
                ),
                child: const Tooltip(message: 'Adicionar arquivo', child: Icon(Icons.add_rounded)),
              ),
            ),
            if (media != null)
              for (final assetId in media.assetIds)
                InputChip(
                  avatar: const Icon(Icons.attach_file_rounded, size: CoeloSize.iconSm),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(assetId, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  deleteButtonTooltipMessage: 'Remover arquivo',
                  onDeleted: () => controller.removeMediaAsset(assetId),
                ),
          ],
        ),
        const PublicationLabel('Público e contexto'),
        PublicationRow(
          icon: Icons.group_outlined,
          title: 'Público e contexto',
          lines: [
            widget.contextLabel ?? 'Instituição selecionada',
            'O servidor valida os vínculos e o escopo',
          ],
        ),
        const SizedBox(height: CoeloSpacing.space3),
        Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          children: [
            for (final entry in _audienceLabels.entries)
              PublicationChip(
                key: Key('circular-audience-${entry.key.name}'),
                label: entry.value,
                selected: draft.audiences.contains(entry.key),
                onTap: () => controller.toggleAudience(entry.key),
              ),
          ],
        ),
        const PublicationLabel('Resposta esperada'),
        Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          children: [
            for (final option in _ResponsePreset.values)
              PublicationChip(
                key: Key('circular-response-${option.name}'),
                label: option.label,
                selected: preset == option,
                onTap: () => _applyPreset(option, questions),
              ),
          ],
        ),
        if (preset == null) ...[
          const SizedBox(height: CoeloSpacing.space3),
          for (final question in questions) ...[
            _QuestionCard(
              key: ValueKey((controller, question.id)),
              controller: controller,
              question: question,
            ),
            const SizedBox(height: CoeloSpacing.space2),
          ],
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('circular-add-question'),
            onPressed: questions.length >= CircularLimits.questions
                ? null
                : () => controller.addQuestion(CircularQuestionKind.singleChoice),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar pergunta'),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        PublicationRow(
          icon: Icons.calendar_today_outlined,
          title: 'Agendamento',
          trailing: TextButton.icon(
            key: const Key('circular-choose-schedule'),
            onPressed: widget.onChooseSchedule == null ? null : _chooseSchedule,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.expand_more_rounded),
            label: Text(_publishAt == null ? 'Publicar agora' : _scheduleLabel(_publishAt!)),
          ),
        ),
        const PublicationLabel('Opções'),
        PublicationToggleRow(
          icon: Icons.description_outlined,
          label: 'Salvar como rascunho',
          value: draft.status == CircularStatus.draft && draft.id.isNotEmpty,
          onChanged: controller.busy ? null : (_) => _save(),
        ),
        if (draft.status != CircularStatus.draft)
          Padding(
            padding: const EdgeInsets.only(top: CoeloSpacing.space2),
            child: Text(
              'Circular ${_statusLabel(draft.status)}: as alterações só valem ao publicar de novo.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  _ResponsePreset? _responsePreset(List<CircularQuestionBlock> questions) {
    if (questions.isEmpty) return _ResponsePreset.readOnly;
    if (questions.length != 1) return null;
    for (final option in _ResponsePreset.values) {
      if (option.matches(questions.first)) return option;
    }
    return null;
  }

  void _applyPreset(_ResponsePreset preset, List<CircularQuestionBlock> questions) {
    final controller = widget.controller;
    for (final question in questions) {
      controller.removeQuestion(question.id);
    }
    if (preset == _ResponsePreset.readOnly) return;
    controller.addQuestion(CircularQuestionKind.singleChoice);
    final question = controller.draft.blocks.whereType<CircularQuestionBlock>().last;
    controller.updateQuestion(question.id, prompt: preset.prompt, required: true);
    for (var index = 0; index < question.options.length; index++) {
      controller.updateOption(question.id, question.options[index].id, preset.options[index]);
    }
  }

  static const _audienceLabels = {
    CircularAudienceKind.families: 'Famílias',
    CircularAudienceKind.students: 'Alunos',
    CircularAudienceKind.schoolStaff: 'Equipe escolar',
    CircularAudienceKind.guardiansOnly: 'Somente responsáveis',
  };

  static String _scheduleLabel(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
  }

  static String _statusLabel(CircularStatus status) => switch (status) {
    CircularStatus.draft => 'em rascunho',
    CircularStatus.scheduled => 'agendada',
    CircularStatus.published => 'publicada',
    CircularStatus.closed => 'encerrada',
    CircularStatus.archived => 'arquivada',
  };

  Widget _feedback() => switch (widget.controller.state) {
    CircularComposerState.saved => const _Feedback(message: 'Rascunho salvo', success: true),
    CircularComposerState.published => const _Feedback(
      message: 'Circular publicada',
      success: true,
    ),
    CircularComposerState.failure
        when widget.controller.errorCode == 'publicationRecoveredWithChanges' =>
      const _Feedback(
        message:
            'Publicação anterior confirmada. Suas alterações ainda não foram publicadas; revise e publique novamente.',
        success: false,
      ),
    CircularComposerState.failure when widget.controller.errorCode == 'publicationPending' =>
      const _Feedback(
        message: 'Confirme a publicação pendente em Publicar antes de salvar novas alterações.',
        success: false,
      ),
    CircularComposerState.failure => const _Feedback(
      message: 'Revise os campos obrigatórios antes de continuar.',
      success: false,
    ),
    CircularComposerState.conflict => const _Feedback(
      message: 'A Circular foi alterada em outro lugar. Recarregue antes de salvar.',
      success: false,
    ),
    _ => const SizedBox.shrink(),
  };
}

final class _QuestionCard extends StatefulWidget {
  const _QuestionCard({required this.controller, required this.question, super.key});
  final CircularComposerController controller;
  final CircularQuestionBlock question;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

final class _QuestionCardState extends State<_QuestionCard> {
  late final TextEditingController _prompt;

  @override
  void initState() {
    super.initState();
    _prompt = TextEditingController(text: widget.question.prompt);
  }

  @override
  void didUpdateWidget(covariant _QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_prompt.text != widget.question.prompt) _prompt.text = widget.question.prompt;
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(CoeloSpacing.space3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.md),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(Icons.drag_indicator_rounded),
            const SizedBox(width: CoeloSpacing.space2),
            const Expanded(child: Text('Pergunta')),
            IconButton(
              tooltip: 'Excluir pergunta',
              color: Theme.of(context).colorScheme.error,
              onPressed: () => widget.controller.removeQuestion(widget.question.id),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space2),
        CoeloFormTextField(
          controller: _prompt,
          labelText: 'Enunciado',
          prefixIcon: Icons.help_outline_rounded,
          maxLength: CircularLimits.questionCharacters,
          onChanged: (value) => widget.controller.updateQuestion(widget.question.id, prompt: value),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        CoeloAdminToggleField(
          label: 'Resposta obrigatória',
          value: widget.question.required,
          onChanged: (value) =>
              widget.controller.updateQuestion(widget.question.id, required: value),
        ),
      ],
    ),
  );
}

/// Resposta esperada da família Publicação, mapeada para o domínio existente:
/// uma pergunta obrigatória de escolha única com duas opções (o mínimo do
/// domínio). "Só leitura" é a ausência de perguntas.
enum _ResponsePreset {
  readOnly('Só leitura', '', ['', '']),
  acknowledge(
    'Confirmar ciência',
    'Confirmo ciência desta circular',
    ['Estou ciente', 'Preciso de mais informações'],
  ),
  acceptDecline('Aceitar / recusar', 'Você aceita?', ['Aceito', 'Recuso']);

  const _ResponsePreset(this.label, this.prompt, this.options);
  final String label;
  final String prompt;
  final List<String> options;

  bool matches(CircularQuestionBlock question) =>
      this != readOnly &&
      question.prompt == prompt &&
      question.options.length == 2 &&
      question.options[0].label == options[0] &&
      question.options[1].label == options[1];
}

final class _CircularAdminPreview extends StatelessWidget {
  const _CircularAdminPreview({required this.draft, this.contextLabel, super.key});
  final CircularDraft draft;
  final String? contextLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final media = draft.blocks.whereType<CircularMediaBlock>().firstOrNull;
    final questions = draft.blocks.whereType<CircularQuestionBlock>().toList(growable: false);
    final institution = (contextLabel ?? '').trim().isEmpty ? 'Instituição' : contextLabel!.trim();
    final action = questions.isEmpty
        ? 'Ler circular'
        : questions.length == 1 && _ResponsePreset.acknowledge.matches(questions.first)
        ? 'Confirmar ciência'
        : questions.length == 1 && _ResponsePreset.acceptDecline.matches(questions.first)
        ? 'Aceitar ou recusar'
        : 'Responder ${questions.length} pergunta${questions.length == 1 ? '' : 's'}';
    return PublicationPreviewPanel(
      title: 'Prévia da circular',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: CoeloSize.avatarSm / 2,
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                child: Text(
                  institution.length >= 2 ? institution.substring(0, 2).toUpperCase() : 'CO',
                  style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: CoeloSpacing.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      institution,
                      style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      draft.audiences.isEmpty
                          ? 'Circular'
                          : 'Circular · ${draft.audiences.map(_audienceLabelOf).join(' · ')}',
                      style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Text(
            draft.title.trim().isEmpty ? 'Título da circular' : draft.title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Text(_bodyText(draft).trim().isEmpty ? 'O conteúdo aparecerá aqui.' : _bodyText(draft)),
          if (media != null && media.assetIds.isNotEmpty) ...[
            const SizedBox(height: CoeloSpacing.space3),
            for (final assetId in media.assetIds)
              Container(
                margin: const EdgeInsets.only(bottom: CoeloSpacing.space1),
                padding: const EdgeInsets.symmetric(
                  horizontal: CoeloSpacing.space3,
                  vertical: CoeloSpacing.space2,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(CoeloRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.attach_file_rounded,
                      size: CoeloSize.iconSm,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: CoeloSpacing.space2),
                    Expanded(child: Text(assetId, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: CoeloSpacing.space3),
          FilledButton.icon(
            onPressed: null,
            style: FilledButton.styleFrom(
              disabledBackgroundColor: colors.primary,
              disabledForegroundColor: colors.onPrimary,
            ),
            icon: const Icon(Icons.check_rounded),
            label: Text(action),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          const PublicationNote('A prévia mostra a circular como a família a verá no Principal.'),
        ],
      ),
    );
  }

  static String _audienceLabelOf(CircularAudienceKind kind) =>
      _SuperadminCircularComposerPageState._audienceLabels[kind] ?? kind.name;
}

final class _Feedback extends StatelessWidget {
  const _Feedback({required this.message, required this.success});
  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: CoeloSpacing.space2),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: success ? colors.primary : colors.error),
        ),
      ),
    );
  }
}

String _bodyText(CircularDraft draft) =>
    draft.blocks.whereType<CircularTextBlock>().firstOrNull?.text ?? '';
