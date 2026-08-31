import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../../shared/presentation/widgets/superadmin_form_frame.dart';

/// Production remains fail-closed until the composition root owns an
/// authoritative mutation capability. The development constructor exercises
/// the complete visual editor without claiming remote persistence.
final class FormsEditorPage extends StatefulWidget {
  const FormsEditorPage({super.key}) : development = false;

  const FormsEditorPage.development({super.key}) : development = true;

  final bool development;

  @override
  State<FormsEditorPage> createState() => _FormsEditorPageState();
}

final class _FormsEditorPageState extends State<FormsEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _context;
  final _catalogSearch = TextEditingController();
  final _sections = <_EditorSectionDraft>[];

  var _selectedSection = 0;
  String? _expandedQuestionId;
  var _previewVisible = false;
  late bool _recurring;
  String? _feedback;
  var _nextId = 20;

  _EditorSectionDraft get _section => _sections[_selectedSection];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.development ? '01 - ANHEMBI - FOTOS' : '');
    _context = TextEditingController(text: widget.development ? 'Todas as unidades' : '');
    _recurring = widget.development;
    _sections.addAll(widget.development ? _fixtureSections() : _neutralSections());
    _expandedQuestionId = _sections.first.questions.last.id;
    _title.addListener(_markChanged);
    _context.addListener(_markChanged);
  }

  @override
  void dispose() {
    _title
      ..removeListener(_markChanged)
      ..dispose();
    _context
      ..removeListener(_markChanged)
      ..dispose();
    _catalogSearch.dispose();
    for (final section in _sections) {
      section.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) => SuperadminFormFrame(
          viewportWidth: constraints.maxWidth,
          bodyMaxWidth: 1180,
          scrollKey: const Key('forms-editor-scroll'),
          navigation: _locked(_sectionNavigation(context, constraints)),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.development) ...[
                const CoeloStatePanel(
                  key: Key('forms-editor-unavailable'),
                  title: 'Editor indisponível',
                  message:
                      'A composição permanece visível com valores neutros, mas edição, publicação e persistência estão bloqueadas.',
                  icon: Icons.lock_outline_rounded,
                ),
                const SizedBox(height: CoeloSpacing.space4),
              ],
              _locked(_editorBody()),
            ],
          ),
          footer: SuperadminFormActionFooter(
            tertiaryAction: TextButton(
              onPressed: widget.development ? _confirmCancel : null,
              child: const Text('Cancelar'),
            ),
            continuationActions: [
              OutlinedButton(
                onPressed: widget.development ? _saveDraftLocally : null,
                child: const Text('Salvar rascunho'),
              ),
              FilledButton(
                onPressed: widget.development ? _validateLocally : null,
                child: const Text('Salvar formulário'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locked(Widget child) =>
      widget.development ? child : IgnorePointer(child: Opacity(opacity: 0.64, child: child));

  Widget _sectionNavigation(BuildContext context, BoxConstraints constraints) {
    final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
    final navigation = _SectionNavigation(
      compact: compact,
      sections: _sections,
      selectedIndex: _selectedSection,
      onSelected: _selectSection,
      onAdd: _addSection,
      onDuplicate: _duplicateSection,
      onDelete: _confirmDeleteSection,
      onMove: _moveSection,
    );
    if (!compact || MediaQuery.textScalerOf(context).scale(1) <= 1.3) return navigation;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.55),
      child: SingleChildScrollView(
        key: const Key('forms-editor-compact-section-scroll'),
        child: navigation,
      ),
    );
  }

  Widget _editorBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          key: const Key('forms-editor-publish'),
          onPressed: widget.development ? _openPublishDialog : null,
          icon: const Icon(Icons.publish_outlined),
          label: const Text('Publicar ou agendar'),
        ),
      ),
      const SizedBox(height: CoeloSpacing.space3),
      _metadata(),
      const SizedBox(height: CoeloSpacing.space6),
      LayoutBuilder(
        builder: (context, constraints) {
          final showPreviewBeside =
              _previewVisible &&
              constraints.maxWidth >= 720 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.3;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _questionCanvas()),
              if (showPreviewBeside) ...[
                const SizedBox(width: CoeloSpacing.space4),
                SizedBox(width: 284, child: _preview()),
              ],
            ],
          );
        },
      ),
      if (_feedback != null) ...[
        const SizedBox(height: CoeloSpacing.space4),
        CoeloStatePanel(
          title: 'Prévia local',
          message: _feedback!,
          icon: Icons.info_outline_rounded,
        ),
      ],
    ],
  );

  Widget _metadata() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              constraints.maxWidth < 720 || MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final fields = [
            CoeloFormTextField(
              controller: _title,
              labelText: 'Nome do formulário',
              prefixIcon: Icons.description_outlined,
              enabled: widget.development,
              onChanged: (_) => _markChanged(),
            ),
            CoeloFormTextField(
              controller: _context,
              labelText: 'Contexto',
              prefixIcon: Icons.account_tree_outlined,
              enabled: widget.development,
              onChanged: (_) => _markChanged(),
            ),
            CoeloAdminToggleField(
              label: 'Recorrente',
              description: 'Gera tarefas agendadas.',
              value: _recurring,
              onChanged: widget.development
                  ? (value) => setState(() {
                      _recurring = value;
                      _feedback = null;
                    })
                  : null,
            ),
          ];
          if (stack) {
            return Column(
              children: [
                for (var index = 0; index < fields.length; index++) ...[
                  fields[index],
                  if (index < fields.length - 1) const SizedBox(height: CoeloSpacing.space4),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: fields[0]),
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(child: fields[1]),
              const SizedBox(width: CoeloSpacing.space3),
              SizedBox(width: 220, child: fields[2]),
            ],
          );
        },
      ),
    );
  }

  Widget _questionCanvas() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_section.title, style: Theme.of(context).textTheme.titleLarge),
              if (_section.description.isNotEmpty)
                Text(
                  _section.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          );
          final previewAction = OutlinedButton.icon(
            key: const Key('forms-editor-toggle-preview'),
            onPressed: _togglePreview,
            icon: Icon(_previewVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            label: Text(_previewVisible ? 'Ocultar prévia' : 'Visualizar prévia'),
          );
          if (constraints.maxWidth < 620 || MediaQuery.textScalerOf(context).scale(1) > 1.3) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: CoeloSpacing.space3),
                previewAction,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              const SizedBox(width: CoeloSpacing.space3),
              previewAction,
            ],
          );
        },
      ),
      const SizedBox(height: CoeloSpacing.space4),
      for (var index = 0; index < _section.questions.length; index++) ...[
        _QuestionCard(
          key: ValueKey(_section.questions[index].id),
          question: _section.questions[index],
          expanded: _expandedQuestionId == _section.questions[index].id,
          canMoveUp: index > 0,
          canMoveDown: index < _section.questions.length - 1,
          onToggle: () => setState(() {
            _expandedQuestionId = _expandedQuestionId == _section.questions[index].id
                ? null
                : _section.questions[index].id;
          }),
          onMoveUp: () => _moveQuestion(index, index - 1),
          onMoveDown: () => _moveQuestion(index, index + 1),
          onMoveToSection: () => _showMoveQuestionDialog(index),
          onDuplicate: () => _duplicateQuestion(index),
          onDelete: () => _confirmDeleteQuestion(index),
          onChanged: _markChanged,
        ),
        const SizedBox(height: CoeloSpacing.space3),
      ],
      CoeloAdminCreateAction(
        key: const Key('forms-editor-add-question'),
        label: 'Adicionar pergunta',
        description: 'Escolha um tipo do catálogo aprovado.',
        variant: CoeloAdminCreateActionVariant.banner,
        onPressed: _showQuestionCatalog,
      ),
    ],
  );

  Widget _preview() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('forms-editor-preview'),
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Prévia do formulário', style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                tooltip: 'Ocultar prévia',
                onPressed: () => setState(() => _previewVisible = false),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(
            _title.text.trim().isEmpty ? 'Formulário sem título' : _title.text.trim(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: CoeloSpacing.space1),
          Text('Seção ${_selectedSection + 1} de ${_sections.length} · ${_section.title}'),
          const SizedBox(height: CoeloSpacing.space4),
          for (var index = 0; index < _section.questions.length; index++) ...[
            Text(
              '${index + 1}. ${_section.questions[index].label.text}'
              '${_section.questions[index].required ? ' *' : ''}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: CoeloSpacing.space2),
            _PreviewAnswer(kind: _section.questions[index].kind),
            if (index < _section.questions.length - 1) const SizedBox(height: CoeloSpacing.space4),
          ],
        ],
      ),
    );
  }

  Future<void> _togglePreview() async {
    final canShowBeside =
        MediaQuery.sizeOf(context).width >= 1280 &&
        MediaQuery.textScalerOf(context).scale(1) <= 1.3;
    if (canShowBeside) {
      setState(() => _previewVisible = !_previewVisible);
      return;
    }
    await showDialog<void>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => CoeloAdminDialogShell(
        title: 'Prévia do formulário',
        maxWidth: 560,
        body: _preview(),
        primaryAction: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar prévia'),
        ),
      ),
    );
  }

  Future<void> _showQuestionCatalog() async {
    _catalogSearch.clear();
    await showDialog<void>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (dialogContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final groups = _catalogGroups
                .map(
                  (group) => (
                    label: group.label,
                    items: group.items
                        .where(
                          (kind) =>
                              _kindLabel(kind).toLowerCase().contains(query.trim().toLowerCase()),
                        )
                        .toList(),
                  ),
                )
                .where((group) => group.items.isNotEmpty)
                .toList();
            return CoeloAdminDialogShell(
              title: 'Adicionar pergunta',
              closeTooltip: 'Fechar catálogo de perguntas',
              maxWidth: 520,
              body: SizedBox(
                key: const Key('forms-editor-question-catalog'),
                height: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CoeloFormTextField(
                      controller: _catalogSearch,
                      labelText: 'Buscar tipo de pergunta',
                      prefixIcon: Icons.search_rounded,
                      onChanged: (value) => setDialogState(() => query = value),
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    Expanded(
                      child: SingleChildScrollView(
                        key: const Key('forms-editor-question-catalog-scroll'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) ...[
                              Text(
                                groups[groupIndex].label,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: CoeloSpacing.space2),
                              for (final kind in groups[groupIndex].items) ...[
                                _CatalogItem(
                                  key: kind == FormItemKind.date
                                      ? const Key('forms-editor-catalog-date')
                                      : null,
                                  kind: kind,
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop();
                                    _addQuestion(kind);
                                  },
                                ),
                                const SizedBox(height: CoeloSpacing.space2),
                              ],
                              if (groupIndex < groups.length - 1)
                                const SizedBox(height: CoeloSpacing.space4),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              primaryAction: FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Fechar catálogo'),
              ),
            );
          },
        );
      },
    );
  }

  void _selectSection(int index) => setState(() {
    _selectedSection = index;
    _expandedQuestionId = _sections[index].questions.firstOrNull?.id;
    _feedback = null;
  });

  void _addSection() {
    final section = _EditorSectionDraft(
      id: 'section-${_nextId++}',
      title: 'Nova seção',
      description: 'Adicione perguntas a esta seção.',
      questions: [],
    );
    setState(() {
      _sections.add(section);
      _selectedSection = _sections.length - 1;
      _expandedQuestionId = null;
      _feedback = null;
    });
  }

  void _duplicateSection() {
    final copy = _section.copy(id: 'section-${_nextId++}', suffix: ' — cópia');
    setState(() {
      _sections.insert(_selectedSection + 1, copy);
      _selectedSection++;
      _expandedQuestionId = copy.questions.firstOrNull?.id;
      _feedback = null;
    });
  }

  void _moveSection(int delta) {
    final target = _selectedSection + delta;
    if (target < 0 || target >= _sections.length) return;
    setState(() {
      final value = _sections.removeAt(_selectedSection);
      _sections.insert(target, value);
      _selectedSection = target;
      _feedback = null;
    });
  }

  Future<void> _confirmDeleteSection() async {
    if (_sections.length <= 1) return;
    final delete = await showDialog<bool>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => CoeloAdminDialogShell(
        title: 'Excluir seção?',
        body: Text('A seção ${_section.title} e todas as perguntas locais nela serão removidas.'),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Manter seção'),
        ),
        primaryAction: FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: const Text('Excluir seção'),
        ),
      ),
    );
    if (delete != true || !mounted) return;
    final removed = _sections.removeAt(_selectedSection);
    removed.dispose();
    setState(() {
      if (_selectedSection >= _sections.length) {
        _selectedSection = _sections.length - 1;
      }
      _expandedQuestionId = _section.questions.firstOrNull?.id;
      _feedback = null;
    });
  }

  void _addQuestion(FormItemKind kind) {
    final question = _EditorQuestionDraft(
      id: 'question-${_nextId++}',
      kind: kind,
      label: _defaultQuestionLabel(kind),
      required: kind != FormItemKind.information,
      branchEnabled: false,
    );
    setState(() {
      _section.questions.add(question);
      _expandedQuestionId = question.id;
      _feedback = null;
    });
  }

  void _moveQuestion(int from, int to) {
    if (to < 0 || to >= _section.questions.length) return;
    setState(() {
      final value = _section.questions.removeAt(from);
      _section.questions.insert(to, value);
      _feedback = null;
    });
  }

  void _duplicateQuestion(int index) {
    final copy = _section.questions[index].copy(id: 'question-${_nextId++}');
    setState(() {
      _section.questions.insert(index + 1, copy);
      _expandedQuestionId = copy.id;
      _feedback = null;
    });
  }

  Future<void> _confirmDeleteQuestion(int index) async {
    final question = _section.questions[index];
    final delete = await showDialog<bool>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => CoeloAdminDialogShell(
        title: 'Excluir pergunta?',
        body: Text('A pergunta ${question.label.text} será removida desta seção.'),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Manter pergunta'),
        ),
        primaryAction: FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: const Text('Excluir pergunta'),
        ),
      ),
    );
    if (delete != true || !mounted) return;
    final removed = _section.questions.removeAt(index);
    removed.dispose();
    setState(() {
      _expandedQuestionId = _section.questions.firstOrNull?.id;
      _feedback = null;
    });
  }

  Future<void> _showMoveQuestionDialog(int index) async {
    if (_sections.length <= 1) return;
    var destination = _sections.indexWhere((section) => section != _section);
    final moved = await showDialog<bool>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CoeloAdminDialogShell(
          title: 'Mover pergunta para seção',
          body: CoeloAdminSingleSelectField<int>(
            label: 'Seção de destino',
            value: destination,
            options: [
              for (var sectionIndex = 0; sectionIndex < _sections.length; sectionIndex++)
                if (sectionIndex != _selectedSection) sectionIndex,
            ],
            optionLabel: (value) => _sections[value].title,
            prefixIcon: Icons.drive_file_move_outline,
            onChanged: (value) => setDialogState(() => destination = value),
          ),
          secondaryAction: OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          primaryAction: FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Mover pergunta'),
          ),
        ),
      ),
    );
    if (moved != true || !mounted) return;
    final question = _section.questions.removeAt(index);
    setState(() {
      _sections[destination].questions.add(question);
      _expandedQuestionId = _section.questions.firstOrNull?.id;
      _feedback = null;
    });
  }

  void _markChanged() {
    if (mounted && _feedback != null) setState(() => _feedback = null);
  }

  void _saveDraftLocally() =>
      setState(() => _feedback = 'Rascunho mantido somente nesta sessão; nenhum dado foi enviado.');

  void _validateLocally() {
    final issues = const FormDefinitionValidator().validate(_localDefinition());
    setState(
      () => _feedback = issues.isEmpty
          ? 'Validação local concluída; a gravação remota continua indisponível.'
          : 'Revise o título, a ordem e os campos obrigatórios antes de salvar.',
    );
  }

  FormDefinition _localDefinition() => FormDefinition(
    id: 'local-preview',
    institutionId: 'local-preview',
    kind: FormKind.form,
    identityMode: FormIdentityMode.identified,
    responseUnit: FormResponseUnit.person,
    title: _title.text.trim(),
    sections: [
      for (var sectionIndex = 0; sectionIndex < _sections.length; sectionIndex++)
        FormSection(
          id: _sections[sectionIndex].id,
          title: _sections[sectionIndex].title,
          description: _sections[sectionIndex].description,
          position: sectionIndex,
          items: [
            for (
              var questionIndex = 0;
              questionIndex < _sections[sectionIndex].questions.length;
              questionIndex++
            )
              FormItem(
                id: _sections[sectionIndex].questions[questionIndex].id,
                kind: _sections[sectionIndex].questions[questionIndex].kind,
                label: _sections[sectionIndex].questions[questionIndex].label.text.trim(),
                position: questionIndex,
                isRequired: _sections[sectionIndex].questions[questionIndex].required,
              ),
          ],
        ),
    ],
  );

  Future<void> _openPublishDialog() async {
    final issues = const FormDefinitionValidator().validate(_localDefinition());
    if (issues.isNotEmpty) {
      setState(
        () => _feedback = 'Revise o título, a ordem e os campos obrigatórios antes de publicar.',
      );
      return;
    }
    final intent = await showDialog<_FormsPublishIntent>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (_) => const _FormsPublishDialog(),
    );
    if (intent == null || !mounted) return;
    setState(() {
      _feedback = intent.scheduledAt == null
          ? 'Publicação concluída somente nesta fixture local; nenhuma persistência remota foi realizada.'
          : 'Publicação agendada localmente para ${_publishDateTime(intent.scheduledAt!)}; nenhuma persistência remota foi realizada.';
    });
  }

  Future<void> _confirmCancel() async {
    final cancel = await showDialog<bool>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => CoeloAdminDialogShell(
        title: 'Descartar alterações locais?',
        body: const Text('A prévia voltará ao conteúdo inicial desta sessão.'),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Continuar editando'),
        ),
        primaryAction: FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: const Text('Descartar'),
        ),
      ),
    );
    if (cancel != true || !mounted) return;
    for (final section in _sections) {
      section.dispose();
    }
    setState(() {
      _sections
        ..clear()
        ..addAll(_fixtureSections());
      _selectedSection = 0;
      _expandedQuestionId = _sections.first.questions.last.id;
      _previewVisible = false;
      _feedback = null;
      _title.text = '01 - ANHEMBI - FOTOS';
      _context.text = 'Todas as unidades';
      _recurring = true;
    });
  }

  List<_EditorSectionDraft> _fixtureSections() => [
    _EditorSectionDraft(
      id: 'section-visit',
      title: 'Visita',
      description: 'Fotos e conferência da execução.',
      questions: [
        _EditorQuestionDraft(
          id: 'photo-before',
          kind: FormItemKind.photo,
          label: 'Foto do antes',
          required: true,
        ),
        _EditorQuestionDraft(
          id: 'photo-after',
          kind: FormItemKind.photo,
          label: 'Foto do depois',
          required: true,
        ),
        _EditorQuestionDraft(
          id: 'extra-point',
          kind: FormItemKind.yesNo,
          label: 'Tem ponto extra?',
          required: true,
          branchEnabled: true,
        ),
      ],
    ),
    _EditorSectionDraft(
      id: 'section-check',
      title: 'Conferência',
      description: 'Confirme os dados observados.',
      questions: [
        _EditorQuestionDraft(
          id: 'visit-date',
          kind: FormItemKind.date,
          label: 'Data da visita',
          required: true,
        ),
        _EditorQuestionDraft(
          id: 'result',
          kind: FormItemKind.singleChoice,
          label: 'Resultado da conferência',
          required: true,
        ),
      ],
    ),
    _EditorSectionDraft(
      id: 'section-notes',
      title: 'Observações',
      description: 'Registre detalhes complementares.',
      questions: [
        _EditorQuestionDraft(
          id: 'notes',
          kind: FormItemKind.shortText,
          label: 'Observação principal',
          required: false,
        ),
      ],
    ),
  ];

  List<_EditorSectionDraft> _neutralSections() => [
    _EditorSectionDraft(
      id: 'neutral-section',
      title: 'Seção sem dados disponíveis',
      description: 'O conteúdo autorizado será carregado quando a integração estiver disponível.',
      questions: [
        _EditorQuestionDraft(
          id: 'neutral-question',
          kind: FormItemKind.shortText,
          label: 'Pergunta sem conteúdo carregado',
          required: false,
        ),
      ],
    ),
  ];
}

final class _FormsPublishIntent {
  const _FormsPublishIntent({this.scheduledAt});

  final DateTime? scheduledAt;
}

final class _FormsPublishDialog extends StatefulWidget {
  const _FormsPublishDialog();

  @override
  State<_FormsPublishDialog> createState() => _FormsPublishDialogState();
}

final class _FormsPublishDialogState extends State<_FormsPublishDialog> {
  bool _scheduled = false;
  DateTime? _scheduledAt;

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    title: 'Publicar formulário',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Esta ação altera somente a fixture local do /dev. Nenhuma publicação ou notificação remota será executada.',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          children: [
            ChoiceChip(
              key: const Key('forms-editor-publish-now'),
              label: const Text('Publicar agora'),
              selected: !_scheduled,
              onSelected: (_) => setState(() => _scheduled = false),
            ),
            ChoiceChip(
              key: const Key('forms-editor-publish-scheduled'),
              label: const Text('Agendar publicação'),
              selected: _scheduled,
              onSelected: (_) => setState(() => _scheduled = true),
            ),
          ],
        ),
        if (_scheduled) ...[
          const SizedBox(height: CoeloSpacing.space4),
          CoeloDateTimeField(
            value: _scheduledAt,
            currentDate: DateTime(2026, 8, 31),
            firstDate: DateTime(2026, 8, 31),
            lastDate: DateTime(2028, 12, 31),
            labelText: 'Data e hora da publicação',
            onChanged: (value) => setState(() => _scheduledAt = value),
          ),
          if (_scheduledAt == null) ...[
            const SizedBox(height: CoeloSpacing.space2),
            Text(
              'Escolha a data e a hora para confirmar o agendamento.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ],
    ),
    secondaryAction: OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(
      key: const Key('forms-editor-confirm-publish'),
      onPressed: _scheduled && _scheduledAt == null
          ? null
          : () => Navigator.of(
              context,
            ).pop(_FormsPublishIntent(scheduledAt: _scheduled ? _scheduledAt : null)),
      child: Text(_scheduled ? 'Agendar publicação' : 'Publicar agora'),
    ),
  );
}

String _publishDateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} às ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

enum _DateRule { free, from, until, range }

final class _EditorSectionDraft {
  _EditorSectionDraft({
    required this.id,
    required this.title,
    required this.description,
    required this.questions,
  });

  final String id;
  final String title;
  final String description;
  final List<_EditorQuestionDraft> questions;

  _EditorSectionDraft copy({required String id, required String suffix}) => _EditorSectionDraft(
    id: id,
    title: '$title$suffix',
    description: description,
    questions: [
      for (var index = 0; index < questions.length; index++)
        questions[index].copy(id: '$id-question-$index'),
    ],
  );

  void dispose() {
    for (final question in questions) {
      question.dispose();
    }
  }
}

final class _EditorQuestionDraft {
  _EditorQuestionDraft({
    required this.id,
    required this.kind,
    required String label,
    required this.required,
    this.branchEnabled = false,
  }) : label = TextEditingController(text: label),
       options = kind == FormItemKind.singleChoice || kind == FormItemKind.multipleChoice
           ? [TextEditingController(text: 'Opção 1'), TextEditingController(text: 'Opção 2')]
           : [];

  final String id;
  final FormItemKind kind;
  final TextEditingController label;
  final List<TextEditingController> options;
  final List<_EditorQuestionDraft> branchQuestions = [];
  bool required;
  bool branchEnabled;
  _DateRule dateRule = _DateRule.free;
  DateTime from = DateTime(2026, 8, 1);
  DateTime until = DateTime(2026, 8, 31);

  _EditorQuestionDraft copy({required String id}) {
    final value = _EditorQuestionDraft(
      id: id,
      kind: kind,
      label: '${label.text} — cópia',
      required: required,
      branchEnabled: branchEnabled,
    );
    value
      ..dateRule = dateRule
      ..from = from
      ..until = until;
    for (var index = 0; index < value.options.length && index < options.length; index++) {
      value.options[index].text = options[index].text;
    }
    value.branchQuestions.addAll([
      for (var index = 0; index < branchQuestions.length; index++)
        branchQuestions[index].copy(id: '$id-branch-$index'),
    ]);
    return value;
  }

  void dispose() {
    label.dispose();
    for (final option in options) {
      option.dispose();
    }
    for (final question in branchQuestions) {
      question.dispose();
    }
  }
}

final class _SectionNavigation extends StatelessWidget {
  const _SectionNavigation({
    required this.compact,
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
    required this.onAdd,
    required this.onDuplicate,
    required this.onDelete,
    required this.onMove,
  });

  final bool compact;
  final List<_EditorSectionDraft> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      key: const Key('forms-editor-section-list'),
      width: compact ? double.infinity : 248,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SEÇÕES',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
              IconButton(
                tooltip: 'Mover seção para cima',
                onPressed: selectedIndex > 0 ? () => onMove(-1) : null,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                tooltip: 'Mover seção para baixo',
                onPressed: selectedIndex < sections.length - 1 ? () => onMove(1) : null,
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
              IconButton(
                tooltip: 'Duplicar seção',
                onPressed: onDuplicate,
                icon: const Icon(Icons.copy_outlined),
              ),
              IconButton(
                tooltip: 'Excluir seção',
                onPressed: sections.length > 1 ? onDelete : null,
                color: colors.error,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space2),
          for (var index = 0; index < sections.length; index++) ...[
            Semantics(
              button: true,
              selected: index == selectedIndex,
              label: '${sections[index].title}, ${sections[index].questions.length} perguntas',
              child: OutlinedButton(
                onPressed: () => onSelected(index),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(CoeloSpacing.space3),
                  foregroundColor: index == selectedIndex ? colors.primary : colors.onSurface,
                  backgroundColor: index == selectedIndex
                      ? colors.primaryContainer
                      : colors.surface,
                  side: BorderSide(
                    color: index == selectedIndex ? colors.primary : colors.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      index == selectedIndex
                          ? Icons.radio_button_checked_rounded
                          : Icons.drag_indicator_rounded,
                    ),
                    const SizedBox(width: CoeloSpacing.space2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sections[index].title),
                          Text(
                            '${sections[index].questions.length} perguntas',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: CoeloSpacing.space2),
          ],
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nova seção'),
          ),
        ],
      ),
    );
  }
}

final class _QuestionCard extends StatefulWidget {
  const _QuestionCard({
    required this.question,
    required this.expanded,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onToggle,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onMoveToSection,
    required this.onDuplicate,
    required this.onDelete,
    required this.onChanged,
    super.key,
  });

  final _EditorQuestionDraft question;
  final bool expanded;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onToggle;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onMoveToSection;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

final class _QuestionCardState extends State<_QuestionCard> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: widget.question.kind == FormItemKind.date
          ? const Key('forms-editor-question-date')
          : null,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: widget.expanded ? colors.primary : colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space3),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < 620 || MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final identity = Row(
                  children: [
                    const Icon(Icons.drag_indicator_rounded),
                    const SizedBox(width: CoeloSpacing.space2),
                    _KindIcon(kind: widget.question.kind),
                    const SizedBox(width: CoeloSpacing.space2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.question.label.text,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            _kindLabel(widget.question.kind),
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final actions = Wrap(
                  alignment: WrapAlignment.end,
                  spacing: CoeloSpacing.spaceHalf,
                  children: [
                    IconButton(
                      tooltip: 'Mover pergunta para cima',
                      onPressed: widget.canMoveUp ? widget.onMoveUp : null,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                    IconButton(
                      tooltip: 'Mover pergunta para baixo',
                      onPressed: widget.canMoveDown ? widget.onMoveDown : null,
                      icon: const Icon(Icons.arrow_downward_rounded),
                    ),
                    IconButton(
                      tooltip: 'Mover pergunta para outra seção',
                      onPressed: widget.onMoveToSection,
                      icon: const Icon(Icons.drive_file_move_outline),
                    ),
                    IconButton(
                      tooltip: 'Duplicar pergunta',
                      onPressed: widget.onDuplicate,
                      icon: const Icon(Icons.copy_outlined),
                    ),
                    IconButton(
                      tooltip: 'Excluir pergunta',
                      onPressed: widget.onDelete,
                      color: colors.error,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                    IconButton(
                      tooltip: widget.expanded ? 'Recolher pergunta' : 'Editar pergunta',
                      onPressed: widget.onToggle,
                      icon: Icon(
                        widget.expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                      ),
                    ),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      const SizedBox(height: CoeloSpacing.space2),
                      actions,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: CoeloSpacing.space2),
                    actions,
                  ],
                );
              },
            ),
          ),
          if (widget.expanded) ...[
            Divider(height: 1, color: colors.outlineVariant),
            Padding(padding: const EdgeInsets.all(CoeloSpacing.space4), child: _configuration()),
          ],
        ],
      ),
    );
  }

  Widget _configuration() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CoeloFormTextField(
        controller: widget.question.label,
        labelText: widget.question.kind == FormItemKind.information
            ? 'Título do bloco'
            : 'Pergunta',
        prefixIcon: Icons.help_outline_rounded,
        onChanged: (_) {
          setState(() {});
          widget.onChanged();
        },
      ),
      if (widget.question.kind != FormItemKind.information) ...[
        const SizedBox(height: CoeloSpacing.space3),
        CoeloAdminToggleField(
          label: 'Obrigatória',
          description: 'A resposta é exigida quando a pergunta estiver visível.',
          value: widget.question.required,
          onChanged: (value) {
            setState(() => widget.question.required = value);
            widget.onChanged();
          },
        ),
      ],
      if (widget.question.kind == FormItemKind.date) ...[
        const SizedBox(height: CoeloSpacing.space3),
        _dateConfiguration(),
      ],
      if (widget.question.options.isNotEmpty) ...[
        const SizedBox(height: CoeloSpacing.space3),
        Text('Opções', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: CoeloSpacing.space2),
        for (var index = 0; index < widget.question.options.length; index++) ...[
          CoeloFormTextField(
            controller: widget.question.options[index],
            labelText: 'Opção ${index + 1}',
            prefixIcon: Icons.radio_button_unchecked_rounded,
            onChanged: (_) => widget.onChanged(),
          ),
          if (index < widget.question.options.length - 1)
            const SizedBox(height: CoeloSpacing.space2),
        ],
      ],
      if (_canBranch(widget.question.kind)) ...[
        const SizedBox(height: CoeloSpacing.space3),
        CoeloAdminToggleField(
          label: 'Desdobrar por resposta',
          description: 'Mostre perguntas extras conforme a resposta escolhida.',
          value: widget.question.branchEnabled,
          onChanged: (value) {
            setState(() => widget.question.branchEnabled = value);
            widget.onChanged();
          },
        ),
        if (widget.question.branchEnabled) ...[
          const SizedBox(height: CoeloSpacing.space3),
          _BranchPanel(
            question: widget.question,
            onAdd: () {
              setState(() {
                widget.question.branchQuestions.add(
                  _EditorQuestionDraft(
                    id: '${widget.question.id}-branch-${widget.question.branchQuestions.length}',
                    kind: FormItemKind.shortText,
                    label: 'Pergunta do ramo ${widget.question.branchQuestions.length + 1}',
                    required: false,
                  ),
                );
              });
              widget.onChanged();
            },
            onDelete: (index) {
              final removed = widget.question.branchQuestions.removeAt(index);
              removed.dispose();
              setState(() {});
              widget.onChanged();
            },
          ),
        ],
      ],
      if (widget.question.kind == FormItemKind.photo ||
          widget.question.kind == FormItemKind.gallery) ...[
        const SizedBox(height: CoeloSpacing.space3),
        const CoeloStatePanel(
          title: 'Mídia protegida',
          message:
              'A configuração visual preserva câmera/galeria e até cinco imagens; upload remoto não é simulado.',
          icon: Icons.photo_camera_back_outlined,
        ),
      ],
    ],
  );

  Widget _dateConfiguration() => Column(
    key: ValueKey('forms-editor-date-config-${widget.question.dateRule.name}'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CoeloAdminSingleSelectField<_DateRule>(
        key: const Key('forms-editor-date-rule'),
        label: 'Validação da data',
        value: widget.question.dateRule,
        options: _DateRule.values,
        optionLabel: _dateRuleLabel,
        prefixIcon: Icons.event_available_outlined,
        onChanged: (value) {
          setState(() => widget.question.dateRule = value);
          widget.onChanged();
        },
      ),
      if (widget.question.dateRule != _DateRule.free) ...[
        const SizedBox(height: CoeloSpacing.space3),
        LayoutBuilder(
          builder: (context, constraints) {
            final from = CoeloDateTimeField(
              key: const Key('forms-editor-date-min'),
              value: widget.question.from,
              labelText: widget.question.dateRule == _DateRule.until
                  ? 'Data máxima'
                  : 'Data mínima',
              firstDate: DateTime(2020),
              lastDate: DateTime(2100, 12, 31),
              onChanged: (value) {
                if (value == null) return;
                setState(() => widget.question.from = value);
                widget.onChanged();
              },
            );
            if (widget.question.dateRule != _DateRule.range) return from;
            final until = CoeloDateTimeField(
              key: const Key('forms-editor-date-max'),
              value: widget.question.until,
              labelText: 'Data máxima',
              firstDate: widget.question.from,
              lastDate: DateTime(2100, 12, 31),
              onChanged: (value) {
                if (value == null) return;
                setState(() => widget.question.until = value);
                widget.onChanged();
              },
            );
            if (constraints.maxWidth < 560 || MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Column(
                children: [
                  from,
                  const SizedBox(height: CoeloSpacing.space3),
                  until,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: from),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(child: until),
              ],
            );
          },
        ),
      ],
    ],
  );
}

final class _BranchPanel extends StatelessWidget {
  const _BranchPanel({required this.question, required this.onAdd, required this.onDelete});

  final _EditorQuestionDraft question;
  final VoidCallback onAdd;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(CoeloRadius.md),
        border: Border(left: BorderSide(color: colors.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question.kind == FormItemKind.yesNo ? 'Se Sim' : 'Por opção selecionada',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: CoeloSpacing.space2),
          const Text('Perguntas do ramo permanecem vinculadas a esta resposta.'),
          if (question.branchQuestions.isNotEmpty) ...[
            const SizedBox(height: CoeloSpacing.space3),
            for (var index = 0; index < question.branchQuestions.length; index++) ...[
              Container(
                padding: const EdgeInsets.all(CoeloSpacing.space3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(CoeloRadius.md),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.subdirectory_arrow_right_rounded),
                    const SizedBox(width: CoeloSpacing.space2),
                    Expanded(child: Text(question.branchQuestions[index].label.text)),
                    IconButton(
                      tooltip: 'Excluir pergunta do ramo',
                      onPressed: () => onDelete(index),
                      color: Theme.of(context).colorScheme.error,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
              if (index < question.branchQuestions.length - 1)
                const SizedBox(height: CoeloSpacing.space2),
            ],
          ],
          const SizedBox(height: CoeloSpacing.space2),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar pergunta ao ramo'),
          ),
        ],
      ),
    );
  }
}

final class _CatalogItem extends StatelessWidget {
  const _CatalogItem({required this.kind, required this.onPressed, super.key});

  final FormItemKind kind;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(CoeloSpacing.space3),
    ),
    child: Row(
      children: [
        _KindIcon(kind: kind),
        const SizedBox(width: CoeloSpacing.space3),
        Expanded(child: Text(_kindLabel(kind))),
        const Icon(Icons.add_rounded),
      ],
    ),
  );
}

final class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind});

  final FormItemKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: CoeloSize.touchMin,
      height: CoeloSize.touchMin,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      child: Icon(_kindIcon(kind), color: colors.primary),
    );
  }
}

final class _PreviewAnswer extends StatelessWidget {
  const _PreviewAnswer({required this.kind});

  final FormItemKind kind;

  @override
  Widget build(BuildContext context) {
    if (kind == FormItemKind.information) return const SizedBox.shrink();
    final icon = switch (kind) {
      FormItemKind.photo => Icons.photo_camera_outlined,
      FormItemKind.gallery => Icons.photo_library_outlined,
      FormItemKind.yesNo => Icons.toggle_off_outlined,
      FormItemKind.date => Icons.calendar_today_outlined,
      _ => Icons.edit_outlined,
    };
    return Container(
      constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

const _catalogGroups = [
  (
    label: 'Texto e números',
    items: [
      FormItemKind.shortText,
      FormItemKind.integer,
      FormItemKind.decimal,
      FormItemKind.money,
      FormItemKind.date,
    ],
  ),
  (
    label: 'Escolhas',
    items: [
      FormItemKind.yesNo,
      FormItemKind.singleChoice,
      FormItemKind.multipleChoice,
      FormItemKind.scale,
    ],
  ),
  (label: 'Mídias', items: [FormItemKind.photo, FormItemKind.gallery]),
  (label: 'Estrutura', items: [FormItemKind.information]),
];

String _kindLabel(FormItemKind kind) => switch (kind) {
  FormItemKind.shortText => 'Texto curto',
  FormItemKind.integer => 'Número inteiro',
  FormItemKind.decimal => 'Número decimal',
  FormItemKind.money => 'Dinheiro',
  FormItemKind.date => 'Data',
  FormItemKind.yesNo => 'Sim / Não',
  FormItemKind.singleChoice => 'Única escolha',
  FormItemKind.multipleChoice => 'Múltipla escolha',
  FormItemKind.scale => 'Escala',
  FormItemKind.photo => 'Foto',
  FormItemKind.gallery => 'Galeria',
  FormItemKind.information => 'Bloco informativo',
};

String _defaultQuestionLabel(FormItemKind kind) => switch (kind) {
  FormItemKind.date => 'Data da visita',
  FormItemKind.yesNo => 'Nova pergunta Sim / Não',
  FormItemKind.information => 'Novo bloco informativo',
  _ => 'Nova pergunta de ${_kindLabel(kind).toLowerCase()}',
};

IconData _kindIcon(FormItemKind kind) => switch (kind) {
  FormItemKind.shortText => Icons.title_rounded,
  FormItemKind.integer => Icons.numbers_rounded,
  FormItemKind.decimal => Icons.calculate_outlined,
  FormItemKind.money => Icons.attach_money_rounded,
  FormItemKind.date => Icons.calendar_today_outlined,
  FormItemKind.yesNo => Icons.toggle_on_outlined,
  FormItemKind.singleChoice => Icons.radio_button_checked_rounded,
  FormItemKind.multipleChoice => Icons.check_box_outlined,
  FormItemKind.scale => Icons.linear_scale_rounded,
  FormItemKind.photo => Icons.photo_camera_outlined,
  FormItemKind.gallery => Icons.photo_library_outlined,
  FormItemKind.information => Icons.info_outline_rounded,
};

bool _canBranch(FormItemKind kind) =>
    kind == FormItemKind.yesNo ||
    kind == FormItemKind.singleChoice ||
    kind == FormItemKind.multipleChoice;

String _dateRuleLabel(_DateRule value) => switch (value) {
  _DateRule.free => 'Livre',
  _DateRule.from => 'A partir de',
  _DateRule.until => 'Até',
  _DateRule.range => 'Intervalo permitido',
};
