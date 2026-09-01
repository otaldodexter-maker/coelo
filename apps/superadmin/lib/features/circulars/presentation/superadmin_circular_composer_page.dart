import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
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
    super.key,
  });

  final CircularComposerController controller;
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
  bool _compactPreview = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.controller.draft.title);
    _body = TextEditingController(text: _bodyText(widget.controller.draft));
  }

  @override
  void dispose() {
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
    try {
      await widget.controller.publish(publishAt: _publishAt);
      widget.onPublished?.call();
    } on Object {
      // The controller exposes a user-safe state in the page feedback.
    }
  }

  Future<void> _chooseSchedule() async {
    final choose = widget.onChooseSchedule;
    if (choose == null) return;
    final selected = await choose();
    if (mounted && selected != null) setState(() => _publishAt = selected);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final showSidePreview = constraints.maxWidth >= 1200;
        final editor = _editor();
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Expanded(
                child: showSidePreview
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: editor),
                          const SizedBox(width: CoeloSpacing.space6),
                          SizedBox(
                            width: 360,
                            child: _CircularAdminPreview(
                              key: const Key('superadmin-circular-preview'),
                              draft: widget.controller.draft,
                            ),
                          ),
                        ],
                      )
                    : _compactPreview
                    ? _CircularAdminPreview(
                        key: const Key('superadmin-circular-preview'),
                        draft: widget.controller.draft,
                      )
                    : editor,
              ),
              _feedback(),
              Padding(
                padding: const EdgeInsets.only(top: CoeloSpacing.space3),
                child: SuperadminFormActionFooter(
                  surfaceKey: const Key('circular-publication-footer'),
                  tertiaryAction: TextButton(
                    key: const Key('circular-cancel'),
                    onPressed: widget.controller.busy ? null : widget.onCancel,
                    child: const Text('Cancelar'),
                  ),
                  continuationActions: [
                    if (!showSidePreview)
                      OutlinedButton.icon(
                        key: const Key('circular-toggle-preview'),
                        onPressed: () => setState(() => _compactPreview = !_compactPreview),
                        icon: Icon(
                          _compactPreview ? Icons.edit_outlined : Icons.visibility_outlined,
                        ),
                        label: Text(_compactPreview ? 'Editar' : 'Prévia'),
                      ),
                    OutlinedButton(
                      key: const Key('circular-save-draft'),
                      onPressed: widget.controller.busy ? null : _save,
                      child: const Text('Salvar rascunho'),
                    ),
                    FilledButton(
                      key: const Key('circular-publish'),
                      onPressed: widget.controller.busy ? null : _publish,
                      child: Text(
                        _publishAt?.isAfter(DateTime.now()) ?? false
                            ? 'Agendar circular'
                            : 'Publicar circular',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _editor() {
    final draft = widget.controller.draft;
    final media = draft.blocks.whereType<CircularMediaBlock>().firstOrNull;
    final questions = draft.blocks.whereType<CircularQuestionBlock>().toList(growable: false);
    return SingleChildScrollView(
      key: const Key('superadmin-circular-editor'),
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                draft.id.isEmpty ? 'Publicar circular' : 'Editar circular',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: CoeloSpacing.space1),
              Text(
                'Prepare o conteúdo, o público e a publicação em uma única superfície.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: CoeloSpacing.space5),
              CoeloFormTextField(
                fieldKey: const Key('circular-title'),
                controller: _title,
                labelText: 'Título da circular',
                hintText: 'Renovação de matrícula para 2027',
                prefixIcon: Icons.title_rounded,
                maxLength: CircularLimits.titleCharacters,
                onChanged: widget.controller.updateTitle,
              ),
              const SizedBox(height: CoeloSpacing.space4),
              CoeloFormTextField(
                fieldKey: const Key('circular-body'),
                controller: _body,
                labelText: 'Texto da circular',
                hintText: 'Escreva a comunicação completa.',
                prefixIcon: Icons.notes_rounded,
                maxLength: CircularLimits.bodyCharacters,
                maxLines: 8,
                onChanged: widget.controller.updateBody,
              ),
              const SizedBox(height: CoeloSpacing.space5),
              _Section(
                title: 'Arquivos e mídia',
                subtitle: 'Fotos, vídeos ou documentos · ${media?.assetIds.length ?? 0}/4',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('circular-pick-files'),
                      onPressed: media != null && media.assetIds.length >= CircularLimits.files
                          ? null
                          : widget.onPickFiles,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Adicionar arquivo'),
                    ),
                    if (media != null)
                      for (final assetId in media.assetIds)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.attach_file_rounded),
                          title: Text(assetId, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            tooltip: 'Remover arquivo',
                            color: Theme.of(context).colorScheme.error,
                            onPressed: () => widget.controller.removeMediaAsset(assetId),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _Section(
                title: 'Perguntas',
                subtitle: '${questions.length}/10 perguntas',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final question in questions) ...[
                      _QuestionCard(controller: widget.controller, question: question),
                      const SizedBox(height: CoeloSpacing.space3),
                    ],
                    OutlinedButton.icon(
                      key: const Key('circular-add-question'),
                      onPressed: questions.length >= CircularLimits.questions
                          ? null
                          : () => widget.controller.addQuestion(CircularQuestionKind.singleChoice),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Adicionar pergunta'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _AudienceSection(controller: widget.controller),
              const SizedBox(height: CoeloSpacing.space4),
              _Section(
                title: 'Agendamento',
                subtitle: _publishAt == null
                    ? 'Publicar assim que a revisão for confirmada.'
                    : 'Publicação futura selecionada.',
                child: OutlinedButton.icon(
                  onPressed: widget.onChooseSchedule == null ? null : _chooseSchedule,
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(_publishAt == null ? 'Escolher data e hora' : 'Alterar agendamento'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feedback() => switch (widget.controller.state) {
    CircularComposerState.saved => const _Feedback(message: 'Rascunho salvo', success: true),
    CircularComposerState.published => const _Feedback(
      message: 'Circular publicada',
      success: true,
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

final class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

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
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          child,
        ],
      ),
    );
  }
}

final class _QuestionCard extends StatefulWidget {
  const _QuestionCard({required this.controller, required this.question});
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

final class _AudienceSection extends StatelessWidget {
  const _AudienceSection({required this.controller});
  final CircularComposerController controller;

  @override
  Widget build(BuildContext context) {
    const labels = {
      CircularAudienceKind.families: 'Famílias e responsáveis',
      CircularAudienceKind.guardiansOnly: 'Somente responsáveis',
      CircularAudienceKind.students: 'Alunos',
      CircularAudienceKind.schoolStaff: 'Equipe autorizada',
    };
    return _Section(
      title: 'Público e contexto',
      subtitle: 'O servidor valida os vínculos e o escopo institucional.',
      child: Column(
        children: [
          for (final entry in labels.entries)
            CoeloAdminToggleField(
              key: Key('circular-audience-${entry.key.name}'),
              label: entry.value,
              value: controller.draft.audiences.contains(entry.key),
              onChanged: (_) => controller.toggleAudience(entry.key),
            ),
        ],
      ),
    );
  }
}

final class _CircularAdminPreview extends StatelessWidget {
  const _CircularAdminPreview({required this.draft, super.key});
  final CircularDraft draft;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Container(
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
              'Prévia da circular',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: CoeloSpacing.space4),
            Icon(Icons.description_outlined, color: colors.primary, size: 32),
            const SizedBox(height: CoeloSpacing.space3),
            Text(
              draft.title.trim().isEmpty ? 'Título da circular' : draft.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: CoeloSpacing.space3),
            Text(_bodyText(draft).trim().isEmpty ? 'O conteúdo aparecerá aqui.' : _bodyText(draft)),
            const SizedBox(height: CoeloSpacing.space4),
            Text(
              '${draft.blocks.whereType<CircularMediaBlock>().firstOrNull?.assetIds.length ?? 0} arquivos · ${draft.blocks.whereType<CircularQuestionBlock>().length} perguntas',
            ),
          ],
        ),
      ),
    );
  }
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
