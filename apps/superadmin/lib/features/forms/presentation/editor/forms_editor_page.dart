import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../data/development_forms_api.dart';
import '../../data/forms_authoring_api.dart';
import '../../data/forms_editor_context.dart';

/// Production remains fail-closed until the composition root owns an
/// authoritative mutation capability. The development constructor exercises
/// the complete visual editor without claiming remote persistence.
final class FormsEditorPage extends StatefulWidget {
  const FormsEditorPage({this.api, this.formId, super.key})
    : development = false,
      authoringApi = null;

  const FormsEditorPage.authoring({required this.authoringApi, this.formId, super.key})
    : development = false,
      api = null;

  const FormsEditorPage.development({this.formId, super.key})
    : development = true,
      api = null,
      authoringApi = null;

  final bool development;
  final String? formId;
  final FormsApi? api;
  final FormsAuthoringApi? authoringApi;

  @override
  State<FormsEditorPage> createState() => _FormsEditorPageState();
}

final class _FormsEditorPageState extends State<FormsEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _context;
  final _catalogSearch = TextEditingController();
  final _sections = <_EditorSectionDraft>[];
  FormsEditorContext? _editorContext;
  FormsAuthoringEditor? _authoringEditor;
  var _authoringDenied = false;
  FormCommand<FormDefinition>? _pendingAuthoringSave;
  Timer? _autosaveTimer;
  var _autosavePaused = false;
  var _draftChanged = false;
  var _confirmingDiscard = false;
  String? _observedDraft;
  FormsAuthoringInstitution? _creationInstitution;
  FormsAuthoringInstitutionPage? _institutionPage;
  final _institutionSearch = TextEditingController();
  var _institutionQueryGeneration = 0;
  var _newFormId = _newRequestId();
  FormDefinition? _definition;
  String? _institutionId;
  var _loading = false;
  var _saving = false;
  var _contextGeneration = 0;
  final _ownedOverlays = <(NavigatorState, Route<dynamic>)>{};

  var _selectedSection = 0;
  String? _expandedQuestionId;
  var _previewVisible = false;
  late bool _recurring;
  late _FormsEditorPeriodicity _periodicity;
  late DateTime? _firstOccurrenceAt;
  late Set<int> _weekdays;
  String? _feedback;
  var _nextId = 20;

  _EditorSectionDraft get _section => _sections[_selectedSection];
  FormsEditorInstitution? get _institution =>
      _editorContext?.institutions.where((value) => value.id == _institutionId).firstOrNull;
  bool get _canEdit =>
      widget.development ||
      (!_loading &&
          (widget.authoringApi != null
              ? (!_authoringDenied &&
                    (_authoringEditor?.canManage ?? (_creationInstitution != null)))
              : widget.api != null && _institution?.canManageForms == true));
  bool get _canView => _canEdit || (!_loading && !_authoringDenied && _authoringEditor != null);
  bool get _canPublish => _canEdit && (_institution?.canPublishForms ?? widget.development);

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: widget.development
          ? developmentFormTitle(widget.formId, fallback: '01 - ANHEMBI - FOTOS')
          : '',
    );
    _context = TextEditingController(text: widget.development ? 'Todas as unidades' : '');
    _recurring = widget.development;
    _periodicity = _FormsEditorPeriodicity.weekly;
    _firstOccurrenceAt = widget.development ? DateTime(2026, 9, 8, 8) : null;
    _weekdays = {DateTime.monday, DateTime.wednesday};
    _sections.addAll(widget.development ? _fixtureSections() : _neutralSections());
    _expandedQuestionId = _sections.first.questions.last.id;
    _title.addListener(_markChanged);
    _context.addListener(_markChanged);
    if (!widget.development) unawaited(_loadProduction());
  }

  Future<void> _loadProduction() async {
    _autosaveTimer?.cancel();
    final generation = ++_contextGeneration;
    final authoring = widget.authoringApi;
    if (authoring != null) {
      await _loadAuthoring(authoring, generation);
      return;
    }
    final api = widget.api;
    final formId = widget.formId;
    if (api == null || api is! FormsEditorContextApi) {
      setState(
        () => _feedback = 'A composição produtiva do editor não recebeu um contexto autorizado.',
      );
      return;
    }
    final contextApi = api as FormsEditorContextApi;
    setState(() => _loading = true);
    try {
      final editorContext = await contextApi.getEditorContext();
      if (!_isCurrentContext(generation)) return;
      final projection = formId == null ? null : await api.getEditor(formId);
      if (!_isCurrentContext(generation)) return;
      final initialInstitutionId =
          projection?.definition.institutionId ??
          editorContext.institutions.where((value) => value.canManageForms).firstOrNull?.id;
      if (initialInstitutionId == null) {
        setState(
          () => _feedback = 'Você não possui instituição autorizada para criar formulários.',
        );
        return;
      }
      final authorized = editorContext.institutions.any(
        (value) => value.id == initialInstitutionId && value.canManageForms,
      );
      if (!authorized) {
        setState(
          () => _feedback = 'Você não possui instituição autorizada para editar este formulário.',
        );
        return;
      }
      setState(() {
        _editorContext = editorContext;
        _institutionId = initialInstitutionId;
        if (projection != null) _applyDefinition(projection.definition);
        _feedback = null;
      });
    } on FormApiException catch (error) {
      if (_isCurrentContext(generation)) setState(() => _feedback = error.message);
    } finally {
      if (_isCurrentContext(generation)) setState(() => _loading = false);
    }
  }

  Future<void> _loadAuthoring(FormsAuthoringApi api, int generation) async {
    final formId = widget.formId ?? _definition?.id;
    setState(() => _loading = true);
    try {
      if (formId == null) {
        await _loadAuthoringInstitutions(api, generation);
        return;
      }
      final editor = await api.getEditor(formId);
      if (!_isCurrentContext(generation)) return;
      setState(() {
        _authoringEditor = editor;
        _authoringDenied = false;
        _institutionId = editor.institution.id;
        // Reauthorization is not permission to discard local edits or replace
        // the baseline of an unresolved command with a different snapshot.
        if (_pendingAuthoringSave == null) _applyDefinition(editor.definition);
        _feedback = null;
      });
    } on FormApiException catch (error) {
      if (_isCurrentContext(generation)) setState(() => _feedback = error.message);
    } finally {
      if (_isCurrentContext(generation)) setState(() => _loading = false);
    }
  }

  Future<void> _loadAuthoringInstitutions(
    FormsAuthoringApi api,
    int generation, {
    FormsAuthoringInstitutionCursor? cursor,
  }) async {
    final queryGeneration = ++_institutionQueryGeneration;
    final search = _institutionSearch.text;
    setState(() {
      _loading = true;
      _institutionPage = null;
    });
    try {
      final page = await api.listInstitutions(
        FormsAuthoringInstitutionQuery(search: search, cursor: cursor),
      );
      if (!_isCurrentContext(generation) || queryGeneration != _institutionQueryGeneration) return;
      setState(() {
        _institutionPage = page;
        if (_authoringDenied) {
          final previous = _creationInstitution;
          _creationInstitution = page.items.where((item) => item.id == previous?.id).firstOrNull;
          _institutionId = _creationInstitution?.id;
        }
        _authoringDenied = false;
        if (cursor == null && search.isEmpty && !page.hasMore && page.items.length == 1) {
          _creationInstitution = page.items.single;
          _institutionId = page.items.single.id;
        }
        _feedback = page.items.isEmpty ? 'Nenhuma instituição encontrada.' : null;
      });
    } on FormApiException catch (error) {
      if (_isCurrentContext(generation) && queryGeneration == _institutionQueryGeneration) {
        setState(() {
          if (error.kind == FormApiFailureKind.unauthorized) _authoringDenied = true;
          _feedback = error.message;
        });
      }
    } finally {
      if (_isCurrentContext(generation) && queryGeneration == _institutionQueryGeneration) {
        setState(() => _loading = false);
        if (!_draftChanged) _observedDraft = _draftFingerprint();
        _scheduleAutosave();
      }
    }
  }

  Widget _creationInstitutionPicker() {
    final generation = _contextGeneration;
    final queryGeneration = _institutionQueryGeneration;
    final api = widget.authoringApi!;
    final page = _institutionPage;
    bool current() =>
        _isCurrentContext(generation) &&
        queryGeneration == _institutionQueryGeneration &&
        identical(page, _institutionPage) &&
        identical(api, widget.authoringApi) &&
        !_loading &&
        _pendingAuthoringSave == null &&
        _definition == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoeloFormTextField(
          controller: _institutionSearch,
          labelText: 'Buscar instituição',
          prefixIcon: Icons.search_rounded,
          onChanged: (_) {
            if (!current()) return;
            setState(() {
              _institutionQueryGeneration++;
              _institutionPage = null;
            });
          },
          enabled: !_loading && _pendingAuthoringSave == null,
        ),
        Wrap(
          spacing: CoeloSpacing.space2,
          children: [
            OutlinedButton(
              onPressed: !_loading && _pendingAuthoringSave == null
                  ? () {
                      if (current()) _loadAuthoringInstitutions(api, generation);
                    }
                  : null,
              child: const Text('Buscar instituições'),
            ),
            if (_institutionPage?.hasMore == true)
              OutlinedButton(
                onPressed: !_loading && _pendingAuthoringSave == null
                    ? () {
                        if (current()) {
                          _loadAuthoringInstitutions(api, generation, cursor: page!.nextCursor);
                        }
                      }
                    : null,
                child: const Text('Próximas instituições'),
              ),
          ],
        ),
        Wrap(
          spacing: CoeloSpacing.space2,
          children: [
            for (final institution
                in _institutionPage?.items ?? const <FormsAuthoringInstitution>[])
              TextButton(
                onPressed: !_loading && _pendingAuthoringSave == null
                    ? () {
                        if (!current() || !page!.items.any((item) => item.id == institution.id)) {
                          return;
                        }
                        setState(() {
                          _creationInstitution = institution;
                          _institutionId = institution.id;
                          _feedback = null;
                        });
                      }
                    : null,
                child: Text(institution.publicName),
              ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space4),
      ],
    );
  }

  bool _isCurrentContext(int generation) => mounted && generation == _contextGeneration;

  @override
  void didUpdateWidget(covariant FormsEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.api, widget.api) &&
        identical(oldWidget.authoringApi, widget.authoringApi) &&
        oldWidget.formId == widget.formId &&
        oldWidget.development == widget.development) {
      return;
    }
    _contextGeneration++;
    _autosaveTimer?.cancel();
    _autosavePaused = false;
    _draftChanged = false;
    _confirmingDiscard = false;
    _observedDraft = null;
    _dismissOwnedOverlays();
    _editorContext = null;
    _authoringEditor = null;
    _authoringDenied = false;
    _pendingAuthoringSave = null;
    _creationInstitution = null;
    _institutionPage = null;
    _institutionQueryGeneration++;
    _institutionSearch.clear();
    _newFormId = _newRequestId();
    _definition = null;
    _institutionId = null;
    _loading = false;
    _saving = false;
    _feedback = null;
    _selectedSection = 0;
    _previewVisible = false;
    _catalogSearch.clear();
    _title.text = widget.development
        ? developmentFormTitle(widget.formId, fallback: '01 - ANHEMBI - FOTOS')
        : '';
    _context.text = widget.development ? 'Todas as unidades' : '';
    _recurring = widget.development;
    _periodicity = _FormsEditorPeriodicity.weekly;
    _firstOccurrenceAt = widget.development ? DateTime(2026, 9, 8, 8) : null;
    _weekdays = {DateTime.monday, DateTime.wednesday};
    for (final section in _sections) {
      section.dispose();
    }
    _sections
      ..clear()
      ..addAll(widget.development ? _fixtureSections() : _neutralSections());
    _expandedQuestionId = _sections.first.questions.last.id;
    if (!widget.development) unawaited(_loadProduction());
  }

  @override
  void dispose() {
    _contextGeneration++;
    _autosaveTimer?.cancel();
    _dismissOwnedOverlays();
    _title
      ..removeListener(_markChanged)
      ..dispose();
    _context
      ..removeListener(_markChanged)
      ..dispose();
    _catalogSearch.dispose();
    _institutionSearch.dispose();
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
          navigation: widget.authoringApi != null && !_canView
              ? const SizedBox.shrink()
              : _canView && !_canEdit
              ? Wrap(
                  children: [
                    for (var index = 0; index < _sections.length; index++)
                      TextButton(
                        onPressed: () => _selectSection(index),
                        child: Text(_sections[index].title),
                      ),
                  ],
                )
              : _locked(_sectionNavigation(context, constraints)),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.authoringApi != null && widget.formId == null && _definition == null)
                _creationInstitutionPicker(),
              if (!widget.development && (_loading || !_canView)) ...[
                CoeloStatePanel(
                  key: Key('forms-editor-unavailable'),
                  title: _loading ? 'Carregando formulário' : 'Editor indisponível',
                  message: _loading
                      ? 'Verificando instituições e capacidades autorizadas.'
                      : _feedback ?? 'A edição exige uma instituição autorizada.',
                  icon: _loading ? null : Icons.lock_outline_rounded,
                  loading: _loading,
                ),
                const SizedBox(height: CoeloSpacing.space4),
                if (widget.authoringApi != null && !_loading)
                  OutlinedButton(onPressed: _loadProduction, child: const Text('Revalidar acesso')),
              ],
              if (widget.authoringApi == null || _canView) _locked(_editorBody()),
            ],
          ),
          footer: SuperadminFormActionFooter(
            tertiaryAction: TextButton(
              onPressed: _canView && !_canEdit
                  ? () => Navigator.of(context).maybePop()
                  : _canEdit && !_saving
                  ? _confirmCancel
                  : null,
              child: Text(_canView && !_canEdit ? 'Voltar' : 'Cancelar'),
            ),
            continuationActions: [
              OutlinedButton(
                onPressed: _canEdit && !_saving ? _saveDraft : null,
                child: const Text('Salvar rascunho'),
              ),
              FilledButton(
                onPressed: _canEdit && !_saving
                    ? (widget.development ? _validateLocally : _saveDraft)
                    : null,
                child: Text(_saving ? 'Salvando…' : 'Salvar formulário'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locked(Widget child) => _canEdit
      ? child
      : ExcludeFocus(
          child: IgnorePointer(child: Opacity(opacity: 0.64, child: child)),
        );

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
      onReorder: _reorderSection,
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
          onPressed: _canPublish && !_saving ? _openPublishDialog : null,
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
          title: widget.authoringApi == null ? 'Prévia local' : 'Estado do rascunho',
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
            if (widget.authoringApi != null)
              CoeloAdminSingleSelectField<String>(
                key: const Key('forms-editor-institution'),
                label: 'Instituição',
                value: _institutionId ?? '',
                options: [?_institutionId],
                optionLabel: (_) =>
                    _authoringEditor?.institution.publicName ??
                    _creationInstitution?.publicName ??
                    '',
                prefixIcon: Icons.account_balance_outlined,
                enabled: false,
                onChanged: (_) {},
              )
            else if (!widget.development)
              CoeloAdminSingleSelectField<String>(
                key: const Key('forms-editor-institution'),
                label: 'Instituição',
                value: _institutionId ?? '',
                options: [
                  for (final institution
                      in _editorContext?.institutions ?? const <FormsEditorInstitution>[])
                    if (institution.canManageForms) institution.id,
                ],
                optionLabel: (id) =>
                    _editorContext?.institutions
                        .where((institution) => institution.id == id)
                        .firstOrNull
                        ?.name ??
                    id,
                prefixIcon: Icons.account_balance_outlined,
                enabled:
                    !_loading &&
                    (_editorContext?.institutions.any((value) => value.canManageForms) ?? false),
                onChanged: (value) => setState(() {
                  _institutionId = value;
                  _feedback = null;
                }),
              ),
            CoeloFormTextField(
              controller: _title,
              labelText: 'Nome do formulário',
              prefixIcon: Icons.description_outlined,
              enabled: _canEdit,
              onChanged: (_) => _markChanged(),
            ),
            CoeloFormTextField(
              controller: _context,
              labelText: 'Contexto',
              prefixIcon: Icons.account_tree_outlined,
              enabled: _canEdit,
              onChanged: (_) => _markChanged(),
            ),
            CoeloAdminToggleField(
              label: 'Gerar ocorrências',
              description: 'Cria aberturas recorrentes para a rotina de cuidado.',
              value: _recurring,
              onChanged: _canEdit && widget.authoringApi == null
                  ? (value) => setState(() {
                      _recurring = value;
                      _feedback = null;
                    })
                  : null,
            ),
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stack)
                for (var index = 0; index < fields.length; index++) ...[
                  fields[index],
                  if (index < fields.length - 1) const SizedBox(height: CoeloSpacing.space4),
                ]
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: CoeloSpacing.space3),
                    Expanded(child: fields[1]),
                    const SizedBox(width: CoeloSpacing.space3),
                    if (fields.length == 4) ...[
                      SizedBox(width: 220, child: fields[2]),
                      const SizedBox(width: CoeloSpacing.space3),
                    ],
                    SizedBox(width: 220, child: fields.last),
                  ],
                ),
              if (_recurring) ...[
                const SizedBox(height: CoeloSpacing.space4),
                _occurrenceSchedule(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _occurrenceSchedule() => LayoutBuilder(
    builder: (context, constraints) {
      final stack = constraints.maxWidth < 720 || MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final startsAt = CoeloDateTimeField(
        key: const Key('forms-editor-first-occurrence'),
        value: _firstOccurrenceAt,
        currentDate: DateTime(2026, 8, 31),
        firstDate: DateTime(2026, 8, 31),
        lastDate: DateTime(2028, 12, 31),
        labelText: 'Primeira ocorrência',
        enabled: _canEdit,
        onChanged: (value) => setState(() {
          _firstOccurrenceAt = value;
          _feedback = null;
        }),
      );
      final periodicity = CoeloAdminSingleSelectField<_FormsEditorPeriodicity>(
        key: const Key('forms-editor-periodicity'),
        label: 'Periodicidade',
        value: _periodicity,
        options: _FormsEditorPeriodicity.values,
        optionLabel: _periodicityLabel,
        prefixIcon: Icons.repeat_rounded,
        enabled: _canEdit,
        onChanged: (value) => setState(() {
          _periodicity = value;
          _feedback = null;
        }),
      );
      final weekdays = CoeloAdminMultiSelectField<int>(
        key: const Key('forms-editor-weekdays'),
        label: 'Dias da semana',
        options: const [1, 2, 3, 4, 5, 6, 7],
        selectedValues: _weekdays,
        optionLabel: _weekdayLabel,
        enabled: _canEdit && _periodicity == _FormsEditorPeriodicity.weekly,
        onChanged: (value) => setState(() {
          _weekdays = value;
          _feedback = null;
        }),
      );
      if (stack) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            startsAt,
            const SizedBox(height: CoeloSpacing.space4),
            periodicity,
            if (_periodicity == _FormsEditorPeriodicity.weekly) ...[
              const SizedBox(height: CoeloSpacing.space4),
              weekdays,
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: startsAt),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(child: periodicity),
          if (_periodicity == _FormsEditorPeriodicity.weekly) ...[
            const SizedBox(width: CoeloSpacing.space3),
            Expanded(child: weekdays),
          ],
        ],
      );
    },
  );

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
      ReorderableListView.builder(
        key: const Key('forms-editor-question-reorder-list'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: _section.questions.length,
        onReorderItem: _reorderQuestion,
        itemBuilder: (context, index) => Padding(
          key: ValueKey(_section.questions[index].id),
          padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
          child: _questionTree(_section.questions, index),
        ),
      ),
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
    final questions = _flattenQuestions(_section.questions).toList();
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
          for (var index = 0; index < questions.length; index++) ...[
            Text(
              '${index + 1}. ${questions[index].label.text}'
              '${questions[index].required ? ' *' : ''}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (questions[index].loadedConditions.isNotEmpty)
              Text('Pergunta condicionada', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: CoeloSpacing.space2),
            _PreviewAnswer(kind: questions[index].kind),
            if (index < questions.length - 1) const SizedBox(height: CoeloSpacing.space4),
          ],
        ],
      ),
    );
  }

  Future<T?> _showOwnedDialog<T>({required WidgetBuilder builder, Color? barrierColor}) async {
    final generation = _contextGeneration;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<T>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: (context) =>
          _isCurrentContext(generation) ? builder(context) : const SizedBox.shrink(),
      barrierColor: barrierColor,
    );
    final entry = (navigator, route as Route<dynamic>);
    _ownedOverlays.add(entry);
    try {
      final result = await navigator.push<T>(route);
      await route.completed;
      return result;
    } finally {
      _ownedOverlays.remove(entry);
    }
  }

  void _dismissOwnedOverlays() {
    for (final (navigator, route) in _ownedOverlays.toList(growable: false)) {
      if (route.isActive) navigator.removeRoute(route);
    }
    _ownedOverlays.clear();
  }

  Future<void> _togglePreview() async {
    final canShowBeside =
        MediaQuery.sizeOf(context).width >= 1280 &&
        MediaQuery.textScalerOf(context).scale(1) <= 1.3;
    if (canShowBeside) {
      setState(() => _previewVisible = !_previewVisible);
      return;
    }
    await _showOwnedDialog<void>(
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
    final generation = _contextGeneration;
    _catalogSearch.clear();
    await _showOwnedDialog<void>(
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
                      onChanged: (value) {
                        if (_isCurrentContext(generation)) setDialogState(() => query = value);
                      },
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
                                  key: Key('forms-editor-catalog-${kind.name}'),
                                  kind: kind,
                                  onPressed: () {
                                    if (!_isCurrentContext(generation)) return;
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
    _changeDraft(() {
      _sections.add(section);
      _selectedSection = _sections.length - 1;
      _expandedQuestionId = null;
      _feedback = null;
    });
  }

  void _duplicateSection() {
    final copy = _section.copy(id: 'section-${_nextId++}', suffix: ' — cópia');
    _changeDraft(() {
      _sections.insert(_selectedSection + 1, copy);
      _selectedSection++;
      _expandedQuestionId = copy.questions.firstOrNull?.id;
      _feedback = null;
    });
  }

  void _moveSection(int delta) {
    final target = _selectedSection + delta;
    if (target < 0 || target >= _sections.length) return;
    _changeDraft(() {
      final value = _sections.removeAt(_selectedSection);
      _sections.insert(target, value);
      _selectedSection = target;
      _feedback = null;
    });
  }

  void _reorderSection(int from, int to) {
    if (from == to) return;
    _changeDraft(() {
      final value = _sections.removeAt(from);
      _sections.insert(to, value);
      _selectedSection = to;
      _feedback = null;
    });
  }

  Future<void> _confirmDeleteSection() async {
    final generation = _contextGeneration;
    if (_sections.length <= 1) return;
    final delete = await _showOwnedDialog<bool>(
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
    if (delete != true || !_isCurrentContext(generation)) return;
    _changeDraft(() {
      final removed = _sections.removeAt(_selectedSection);
      removed.dispose();
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
    _changeDraft(() {
      _section.questions.add(question);
      _expandedQuestionId = question.id;
      _feedback = null;
    });
  }

  Widget _questionTree(List<_EditorQuestionDraft> siblings, int index, {bool nested = false}) {
    final question = siblings[index];
    final generation = _contextGeneration;
    bool current() =>
        _isCurrentContext(generation) &&
        _sections.any(
          (section) =>
              _flattenQuestions(section.questions).any((item) => identical(item, question)),
        );
    return _QuestionCard(
      key: ValueKey('forms-question-card-${question.id}'),
      index: index,
      question: question,
      expanded: (_canView && !_canEdit) || _expandedQuestionId == question.id,
      canMoveUp: index > 0,
      canMoveDown: index < siblings.length - 1,
      canDrag: !nested,
      onToggle: () => setState(() {
        _expandedQuestionId = _expandedQuestionId == question.id ? null : question.id;
      }),
      onMoveUp: () => _moveQuestionIn(siblings, index, index - 1),
      onMoveDown: () => _moveQuestionIn(siblings, index, index + 1),
      onMoveToSection: nested ? null : () => _showMoveQuestionDialog(index),
      onDuplicate: () => _duplicateQuestionIn(siblings, index),
      onDelete: () => _confirmDeleteQuestion(index, siblings: siblings),
      onChanged: () => _changeDraft(() => _feedback = null),
      branchPanel:
          _canBranch(question.kind) &&
              question.branchEnabled &&
              (_expandedQuestionId == question.id || question.branchQuestions.isNotEmpty)
          ? _BranchPanel(
              question: question,
              triggerSelector: question.kind == FormItemKind.yesNo
                  ? CoeloAdminSingleSelectField<bool>(
                      key: ValueKey('forms-branch-boolean-${question.id}'),
                      label: 'Resposta que revela o próximo ramo',
                      value: question.branchExpectedYesNo,
                      options: const [true, false],
                      optionLabel: (value) => value ? 'Sim' : 'Não',
                      onChanged: (value) {
                        if (!current()) return;
                        setState(() => question.branchExpectedYesNo = value);
                      },
                    )
                  : CoeloAdminSingleSelectField<String?>(
                      key: ValueKey('forms-branch-option-${question.id}'),
                      label: 'Opção que revela o próximo ramo',
                      value: question.branchOptionId,
                      options: [
                        null,
                        for (final option in question.options) question.optionIds[option]!,
                      ],
                      optionLabel: (id) =>
                          id == null ? 'Selecione uma opção' : question.optionLabel(id),
                      onChanged: (id) {
                        if (!current() || (id != null && !question.optionIds.containsValue(id))) {
                          return;
                        }
                        setState(() => question.branchOptionId = id);
                      },
                    ),
              onAdd:
                  question.kind != FormItemKind.yesNo &&
                      !question.optionIds.containsValue(question.branchOptionId)
                  ? null
                  : () {
                      if (!current() ||
                          !question.branchEnabled ||
                          (question.kind != FormItemKind.yesNo &&
                              !question.optionIds.containsValue(question.branchOptionId))) {
                        return;
                      }
                      _changeDraft(() {
                        question.branchQuestions.add(
                          _EditorQuestionDraft(
                            id: _newRequestId(),
                            kind: FormItemKind.shortText,
                            label: 'Pergunta do ramo ${question.branchQuestions.length + 1}',
                            required: false,
                            loadedConditions: [
                              if (question.kind == FormItemKind.yesNo)
                                FormCondition.yesNo(
                                  sourceItemId: question.id,
                                  expected: question.branchExpectedYesNo,
                                )
                              else
                                FormCondition.choice(
                                  sourceItemId: question.id,
                                  optionIds: {question.branchOptionId!},
                                ),
                            ],
                          ),
                        );
                        _feedback = null;
                      });
                    },
              onDelete: (index) =>
                  _confirmDeleteQuestion(index, siblings: question.branchQuestions),
              children: Column(
                children: [
                  for (
                    var childIndex = 0;
                    childIndex < question.branchQuestions.length;
                    childIndex++
                  )
                    Padding(
                      padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
                            child: Text(
                              question.kind == FormItemKind.yesNo
                                  ? (question
                                            .branchQuestions[childIndex]
                                            .loadedConditions
                                            .single
                                            .expectedYesNo!
                                        ? 'Se Sim'
                                        : 'Se Não')
                                  : 'Se “${question.optionLabel(question.branchQuestions[childIndex].loadedConditions.single.optionIds.single)}”',
                            ),
                          ),
                          _questionTree(question.branchQuestions, childIndex, nested: true),
                        ],
                      ),
                    ),
                ],
              ),
            )
          : null,
    );
  }

  void _moveQuestionIn(List<_EditorQuestionDraft> siblings, int from, int to) {
    if (to < 0 || to >= siblings.length) return;
    _changeDraft(() {
      final value = siblings.removeAt(from);
      siblings.insert(to, value);
      _feedback = null;
    });
  }

  void _reorderQuestion(int from, int to) {
    if (from == to) return;
    _changeDraft(() {
      final value = _section.questions.removeAt(from);
      _section.questions.insert(to, value);
      _feedback = null;
    });
  }

  void _duplicateQuestionIn(List<_EditorQuestionDraft> siblings, int index) {
    final copy = siblings[index].copy(id: _newRequestId());
    _changeDraft(() {
      siblings.insert(index + 1, copy);
      _expandedQuestionId = copy.id;
      _feedback = null;
    });
  }

  Future<void> _confirmDeleteQuestion(int index, {List<_EditorQuestionDraft>? siblings}) async {
    final generation = _contextGeneration;
    final questions = siblings ?? _section.questions;
    final question = questions[index];
    final delete = await _showOwnedDialog<bool>(
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
    if (delete != true || !_isCurrentContext(generation)) return;
    _changeDraft(() {
      final removed = questions.removeAt(index);
      removed.dispose();
      _expandedQuestionId = _section.questions.firstOrNull?.id;
      _feedback = null;
    });
  }

  Future<void> _showMoveQuestionDialog(int index) async {
    final generation = _contextGeneration;
    if (_sections.length <= 1) return;
    final destinationLabels = {
      for (var sectionIndex = 0; sectionIndex < _sections.length; sectionIndex++)
        if (sectionIndex != _selectedSection) sectionIndex: _sections[sectionIndex].title,
    };
    var destination = _sections.indexWhere((section) => section != _section);
    final moved = await _showOwnedDialog<bool>(
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CoeloAdminDialogShell(
          title: 'Mover pergunta para seção',
          body: CoeloAdminSingleSelectField<int>(
            label: 'Seção de destino',
            value: destination,
            options: destinationLabels.keys.toList(growable: false),
            optionLabel: (value) => destinationLabels[value]!,
            prefixIcon: Icons.drive_file_move_outline,
            onChanged: (value) {
              if (_isCurrentContext(generation)) setDialogState(() => destination = value);
            },
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
    if (moved != true || !_isCurrentContext(generation)) return;
    _changeDraft(() {
      final question = _section.questions.removeAt(index);
      _sections[destination].questions.add(question);
      _expandedQuestionId = _section.questions.firstOrNull?.id;
      _feedback = null;
    });
  }

  void _changeDraft(VoidCallback mutation) {
    if (!_canEdit) return;
    final previousFeedback = _feedback;
    setState(mutation);
    if (_autosavePaused) _feedback = previousFeedback;
    _markChanged();
  }

  void _markChanged() {
    if (!mounted) return;
    if (widget.authoringApi == null) {
      if (_feedback != null) setState(() => _feedback = null);
      return;
    }
    if (!_canEdit || _confirmingDiscard) return;
    final fingerprint = _draftFingerprint();
    if (_observedDraft == fingerprint) return;
    _observedDraft = fingerprint;
    setState(() {
      _draftChanged = true;
      if (!_autosavePaused) _feedback = 'Alterações ainda não salvas.';
    });
    _scheduleAutosave();
  }

  String _draftFingerprint() {
    final payload = FormDefinitionDto.fromDomain(_localDefinition()).toJson();
    payload.remove('management_version');
    return jsonEncode(payload);
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    if (widget.authoringApi == null ||
        !_canEdit ||
        _autosavePaused ||
        _confirmingDiscard ||
        !_draftChanged ||
        _saving ||
        _pendingAuthoringSave != null) {
      return;
    }
    final generation = _contextGeneration;
    final api = widget.authoringApi;
    _autosaveTimer = Timer(const Duration(milliseconds: 800), () {
      if (!_isCurrentContext(generation) ||
          !identical(api, widget.authoringApi) ||
          !_canEdit ||
          _autosavePaused ||
          !_draftChanged) {
        return;
      }
      unawaited(_saveDraft(automatic: true));
    });
  }

  void _saveDraftLocally() => setState(() {
    final issue = _scheduleIssue;
    _feedback = issue == null
        ? 'Rascunho mantido somente nesta sessão ($_scheduleSummary); nenhum dado foi enviado.'
        : 'Rascunho mantido somente nesta sessão, com agendamento incompleto: $issue Nenhum dado foi enviado.';
  });

  String? get _scheduleIssue {
    if (!_recurring) return null;
    if (_firstOccurrenceAt == null) return 'Informe a primeira ocorrência.';
    if (_periodicity == _FormsEditorPeriodicity.weekly && _weekdays.isEmpty) {
      return 'Selecione pelo menos um dia da semana.';
    }
    return null;
  }

  String get _scheduleSummary {
    if (!_recurring) return 'sem recorrência';
    final occurrence = _firstOccurrenceAt;
    if (occurrence == null) return 'recorrência sem primeira ocorrência';
    final days = _periodicity == _FormsEditorPeriodicity.weekly
        ? ' em ${(_weekdays.toList()..sort()).map(_weekdayLabel).join(', ')}'
        : '';
    return '${_periodicityLabel(_periodicity)}$days, a partir de ${_publishDateTime(occurrence)}';
  }

  void _validateLocally() {
    final issues = const FormDefinitionValidator().validate(_localDefinition());
    final scheduleIssue = _scheduleIssue;
    setState(
      () => _feedback = issues.isNotEmpty
          ? 'Revise o título, a ordem e os campos obrigatórios antes de salvar.'
          : scheduleIssue ??
                'Validação local concluída ($_scheduleSummary); nenhum dado foi enviado.',
    );
  }

  FormDefinition _localDefinition() => FormDefinition(
    id: _definition?.id ?? (widget.authoringApi != null ? _newFormId : ''),
    institutionId: _institutionId ?? '',
    kind: _definition?.kind ?? FormKind.form,
    identityMode: _definition?.identityMode ?? FormIdentityMode.identified,
    responseUnit: _definition?.responseUnit ?? FormResponseUnit.person,
    description: _definition?.description,
    status: _definition?.status ?? FormStatus.draft,
    managementVersion: _definition?.managementVersion ?? 0,
    title: _title.text.trim(),
    sections: [
      for (var sectionIndex = 0; sectionIndex < _sections.length; sectionIndex++)
        FormSection(
          id: _sections[sectionIndex].id,
          title: _sections[sectionIndex].title,
          description: _sections[sectionIndex].description,
          position: sectionIndex,
          items: _sectionItemDefinitions(_sections[sectionIndex]),
        ),
    ],
  );

  List<FormItem> _sectionItemDefinitions(_EditorSectionDraft section) {
    final questions = _flattenQuestions(section.questions).toList();
    return [
      for (var index = 0; index < questions.length; index++)
        _itemDefinition(questions[index], index),
    ];
  }

  FormItem _itemDefinition(_EditorQuestionDraft question, int position) => FormItem(
    id: question.id,
    kind: question.kind,
    label: question.label.text.trim(),
    helpText: question.details.text.trim().isEmpty ? null : question.details.text.trim(),
    position: position,
    isRequired: question.required,
    conditions: question.loadedConditions,
    config: FormItemConfig(
      decimalPlaces: question.loadedConfig.decimalPlaces,
      scaleMin: question.loadedConfig.scaleMin,
      scaleMax: question.loadedConfig.scaleMax,
      scaleMinLabel: question.loadedConfig.scaleMinLabel,
      scaleMaxLabel: question.loadedConfig.scaleMaxLabel,
      allowCamera: question.loadedConfig.allowCamera,
      allowExisting: question.loadedConfig.allowExisting,
      maxImages: question.loadedConfig.maxImages,
      minValue: num.tryParse(question.minimum.text.trim().replaceAll(',', '.')),
      maxValue: num.tryParse(question.maximum.text.trim().replaceAll(',', '.')),
      currency: question.kind == FormItemKind.money ? 'BRL' : null,
    ),
    options: [
      for (var index = 0; index < question.options.length; index++)
        FormOption(
          id: question.optionIds[question.options[index]]!,
          label: question.options[index].text.trim(),
          position: index,
        ),
    ],
  );

  Future<void> _saveDraft({bool automatic = false}) async {
    _autosaveTimer?.cancel();
    final generation = _contextGeneration;
    if (widget.development) {
      _saveDraftLocally();
      return;
    }
    final api = widget.api;
    final authoring = widget.authoringApi;
    if ((api == null && authoring == null) || !_canEdit || _saving) return;
    if (automatic && _autosavePaused) return;
    if (!automatic) _autosavePaused = false;
    final definition = _pendingAuthoringSave?.payload ?? _localDefinition();
    // Quick-poll completeness is a publish gate, not a draft-save gate.
    // Keep structural validation; the backend still authorizes every command.
    final draftIssues = const FormDefinitionValidator()
        .validate(definition)
        .where(
          (issue) => switch (issue.code) {
            FormValidationCode.quickPollIntentRequired ||
            FormValidationCode.quickPollIntentTooLong ||
            FormValidationCode.quickPollRequiresOneQuestion => false,
            _ => true,
          },
        );
    if (draftIssues.isNotEmpty || _hasInvalidChoiceReferences(definition)) {
      _autosavePaused = true;
      setState(
        () => _feedback = 'Revise o título, a ordem e os campos obrigatórios antes de salvar.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final command =
          _pendingAuthoringSave ??
          FormCommand(
            requestId: _newRequestId(),
            expectedVersion: _definition?.managementVersion ?? 0,
            payload: definition,
          );
      if (authoring != null) _pendingAuthoringSave = command;
      final saved = await (authoring != null
          ? authoring.saveDraft(command)
          : api!.saveDraft(command));
      if (!_isCurrentContext(generation)) return;
      final changedSinceCommand =
          authoring != null &&
          jsonEncode(FormDefinitionDto.fromDomain(_localDefinition()).toJson()) !=
              jsonEncode(FormDefinitionDto.fromDomain(command.payload).toJson());
      setState(() {
        _definition = saved;
        _institutionId = saved.institutionId;
        _pendingAuthoringSave = null;
        _draftChanged = changedSinceCommand;
        _observedDraft = _draftFingerprint();
        _feedback = changedSinceCommand
            ? 'Salvamento anterior confirmado. Há alterações locais ainda não salvas.'
            : 'Rascunho salvo.';
      });
    } on FormApiException catch (error) {
      if (_isCurrentContext(generation)) {
        setState(() {
          _autosavePaused = true;
          if (authoring != null && error.kind == FormApiFailureKind.unauthorized) {
            _authoringDenied = true;
          }
          if (error.kind == FormApiFailureKind.validation ||
              error.kind == FormApiFailureKind.conflict) {
            _pendingAuthoringSave = null;
          }
          _feedback = error.message;
        });
      }
    } on Object {
      if (_isCurrentContext(generation)) {
        setState(() {
          _autosavePaused = true;
          _feedback = 'Falha ao salvar. Tente novamente para confirmar o rascunho.';
        });
      }
    } finally {
      if (_isCurrentContext(generation)) {
        setState(() => _saving = false);
        _scheduleAutosave();
      }
    }
  }

  void _applyDefinition(FormDefinition definition) {
    for (final section in _sections) {
      section.dispose();
    }
    _sections
      ..clear()
      ..addAll([
        for (final section in definition.sections)
          _EditorSectionDraft(
            id: section.id,
            title: section.title,
            description: section.description ?? '',
            questions: _hydrateQuestions(section.items),
          ),
      ]);
    if (_sections.isEmpty) _sections.addAll(_neutralSections());
    _definition = definition;
    _title.text = definition.title;
    _selectedSection = 0;
    _expandedQuestionId = _sections.first.questions.firstOrNull?.id;
    _draftChanged = false;
    _observedDraft = _draftFingerprint();
  }

  List<_EditorQuestionDraft> _hydrateQuestions(List<FormItem> items) {
    final roots = <_EditorQuestionDraft>[];
    final ancestors = <_EditorQuestionDraft>[];
    for (final item in items) {
      final draft = _questionDraft(item);
      final condition = item.conditions.length == 1 ? item.conditions.single : null;
      final parentIndex = condition == null
          ? -1
          : ancestors.indexWhere((parent) {
              if (parent.id != condition.sourceItemId) return false;
              return switch (condition.kind) {
                FormConditionKind.yesNo =>
                  condition.expectedYesNo != null && parent.kind == FormItemKind.yesNo,
                FormConditionKind.choice =>
                  (parent.kind == FormItemKind.singleChoice ||
                          parent.kind == FormItemKind.multipleChoice) &&
                      condition.optionIds.length == 1 &&
                      parent.optionIds.containsValue(condition.optionIds.single),
              };
            });
      if (parentIndex >= 0) {
        final parent = ancestors[parentIndex];
        parent.branchQuestions.add(draft);
        parent.branchEnabled = true;
        ancestors.removeRange(parentIndex + 1, ancestors.length);
      } else {
        roots.add(draft);
        ancestors.clear();
      }
      ancestors.add(draft);
    }
    return roots;
  }

  _EditorQuestionDraft _questionDraft(FormItem item) {
    final draft = _EditorQuestionDraft(
      id: item.id,
      kind: item.kind,
      label: item.label,
      required: item.isRequired,
      loadedConfig: item.config,
      loadedConditions: item.conditions,
    );
    draft
      ..details.text = item.helpText ?? ''
      ..minimum.text = item.config.minValue?.toString() ?? ''
      ..maximum.text = item.config.maxValue?.toString() ?? '';
    draft.replaceOptions(item.options);
    return draft;
  }

  Future<void> _openPublishDialog() async {
    final generation = _contextGeneration;
    final issues = const FormDefinitionValidator().validate(_localDefinition());
    if (issues.isNotEmpty) {
      setState(
        () => _feedback = 'Revise o título, a ordem e os campos obrigatórios antes de publicar.',
      );
      return;
    }
    final scheduleIssue = _scheduleIssue;
    if (scheduleIssue != null) {
      setState(() => _feedback = scheduleIssue);
      return;
    }
    final intent = await _showOwnedDialog<_FormsPublishIntent>(
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (_) => _FormsPublishDialog(allowSchedule: widget.development),
    );
    if (intent == null || !_isCurrentContext(generation)) return;
    if (!widget.development) {
      final api = widget.api;
      final definition = _definition;
      if (api == null || definition == null || !_canPublish) return;
      setState(() => _saving = true);
      try {
        final published = await api.publish(
          FormCommand(
            requestId: _newRequestId(),
            expectedVersion: definition.managementVersion,
            payload: FormIdPayload(definition.id),
          ),
        );
        if (!_isCurrentContext(generation)) return;
        setState(() {
          _definition = published;
          _feedback = 'Formulário publicado.';
        });
      } on FormApiException catch (error) {
        if (_isCurrentContext(generation)) setState(() => _feedback = error.message);
      } finally {
        if (_isCurrentContext(generation)) setState(() => _saving = false);
      }
      return;
    }
    setState(() {
      _feedback = intent.scheduledAt == null
          ? 'Publicação concluída somente nesta fixture local; nenhuma persistência remota foi realizada.'
          : 'Publicação agendada localmente para ${_publishDateTime(intent.scheduledAt!)}; nenhuma persistência remota foi realizada.';
    });
  }

  Future<void> _confirmCancel() async {
    if (_pendingAuthoringSave != null) {
      setState(
        () => _feedback = 'Confirme o salvamento anterior antes de descartar alterações locais.',
      );
      return;
    }
    _autosaveTimer?.cancel();
    _confirmingDiscard = true;
    final generation = _contextGeneration;
    final cancel = await _showOwnedDialog<bool>(
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => CoeloAdminDialogShell(
        title: 'Descartar alterações locais?',
        body: Text(
          widget.development
              ? 'A prévia voltará ao conteúdo inicial desta sessão.'
              : 'O editor voltará ao último conteúdo confirmado. Em um formulário novo, os campos voltarão ao estado inicial.',
        ),
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
    if (!_isCurrentContext(generation)) return;
    if (cancel != true) {
      _confirmingDiscard = false;
      _scheduleAutosave();
      return;
    }
    if (!widget.development) {
      setState(() {
        final confirmed = _definition;
        if (confirmed != null) {
          _applyDefinition(confirmed);
          _institutionId = confirmed.institutionId;
        } else {
          for (final section in _sections) {
            section.dispose();
          }
          _sections
            ..clear()
            ..addAll(_neutralSections());
          _title.clear();
          _selectedSection = 0;
          _expandedQuestionId = _sections.first.questions.firstOrNull?.id;
        }
        _context.clear();
        _catalogSearch.clear();
        _previewVisible = false;
        _feedback = null;
        _recurring = false;
        _periodicity = _FormsEditorPeriodicity.weekly;
        _firstOccurrenceAt = null;
        _weekdays = {DateTime.monday, DateTime.wednesday};
        _draftChanged = false;
        _observedDraft = _draftFingerprint();
        _confirmingDiscard = false;
      });
      return;
    }
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
      _periodicity = _FormsEditorPeriodicity.weekly;
      _firstOccurrenceAt = DateTime(2026, 9, 8, 8);
      _weekdays = {DateTime.monday, DateTime.wednesday};
      _confirmingDiscard = false;
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

enum _FormsEditorPeriodicity { daily, weekly, monthly }

String _periodicityLabel(_FormsEditorPeriodicity value) => switch (value) {
  _FormsEditorPeriodicity.daily => 'Diária',
  _FormsEditorPeriodicity.weekly => 'Semanal',
  _FormsEditorPeriodicity.monthly => 'Mensal',
};

String _weekdayLabel(int value) => const {
  DateTime.monday: 'Segunda-feira',
  DateTime.tuesday: 'Terça-feira',
  DateTime.wednesday: 'Quarta-feira',
  DateTime.thursday: 'Quinta-feira',
  DateTime.friday: 'Sexta-feira',
  DateTime.saturday: 'Sábado',
  DateTime.sunday: 'Domingo',
}[value]!;

enum _FormsPublishMode { now, scheduled }

final class _FormsPublishDialog extends StatefulWidget {
  const _FormsPublishDialog({required this.allowSchedule});

  final bool allowSchedule;

  @override
  State<_FormsPublishDialog> createState() => _FormsPublishDialogState();
}

final class _FormsPublishDialogState extends State<_FormsPublishDialog> {
  var _mode = _FormsPublishMode.now;
  DateTime? _scheduledAt;

  bool get _scheduled => _mode == _FormsPublishMode.scheduled;

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    title: 'Publicar formulário',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.allowSchedule
              ? 'Esta ação altera somente a fixture local do /dev. Nenhuma publicação ou notificação remota será executada.'
              : 'A publicação será executada agora pela operação autorizada.',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloAdminSingleSelectField<_FormsPublishMode>(
          key: const Key('forms-editor-publish-mode'),
          label: 'Quando publicar',
          value: _mode,
          options: widget.allowSchedule ? _FormsPublishMode.values : const [_FormsPublishMode.now],
          optionLabel: (value) => switch (value) {
            _FormsPublishMode.now => 'Publicar agora',
            _FormsPublishMode.scheduled => 'Agendar publicação',
          },
          prefixIcon: Icons.publish_outlined,
          onChanged: (value) => setState(() => _mode = value),
        ),
        if (_scheduled) ...[
          const SizedBox(height: CoeloSpacing.space4),
          CoeloDateTimeField(
            key: const Key('forms-editor-publish-scheduled-at'),
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

String _newRequestId() {
  final values = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  final hex = values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

enum _DateRule { free, from, until, range }

bool _hasInvalidChoiceReferences(FormDefinition definition) {
  final items = {
    for (final section in definition.sections)
      for (final item in section.items) item.id: item,
  };
  for (final item in items.values) {
    for (final condition in item.conditions) {
      if (condition.kind != FormConditionKind.choice) continue;
      final source = items[condition.sourceItemId];
      if (source == null ||
          (source.kind != FormItemKind.singleChoice &&
              source.kind != FormItemKind.multipleChoice) ||
          condition.optionIds.isEmpty ||
          !source.options.map((option) => option.id).toSet().containsAll(condition.optionIds)) {
        return true;
      }
    }
  }
  return false;
}

Iterable<_EditorQuestionDraft> _flattenQuestions(Iterable<_EditorQuestionDraft> questions) sync* {
  for (final question in questions) {
    yield question;
    if (_canBranch(question.kind)) {
      yield* _flattenQuestions(question.branchQuestions);
    }
  }
}

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

  _EditorSectionDraft copy({required String id, required String suffix}) {
    final allQuestions = _flattenQuestions(questions).toList();
    final itemIds = {
      for (var index = 0; index < allQuestions.length; index++)
        allQuestions[index].id: '$id-question-$index',
    };
    final optionIds = {
      for (final question in allQuestions)
        for (var index = 0; index < question.options.length; index++)
          question.optionIds[question.options[index]]!: '${itemIds[question.id]}-option-$index',
    };
    return _EditorSectionDraft(
      id: id,
      title: '$title$suffix',
      description: description,
      questions: [
        for (final question in questions)
          question.copy(id: itemIds[question.id]!, itemIdMap: itemIds, optionIdMap: optionIds),
      ],
    );
  }

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
    this.loadedConfig = const FormItemConfig(),
    this.loadedConditions = const [],
  }) : label = TextEditingController(text: label),
       details = TextEditingController(),
       minimum = TextEditingController(),
       maximum = TextEditingController(),
       options = kind == FormItemKind.singleChoice || kind == FormItemKind.multipleChoice
           ? [TextEditingController(text: 'Opção 1'), TextEditingController(text: 'Opção 2')]
           : [] {
    for (var index = 0; index < options.length; index++) {
      optionIds[options[index]] = '$id-option-$index';
    }
  }

  final String id;
  final FormItemKind kind;
  final FormItemConfig loadedConfig;
  final List<FormCondition> loadedConditions;
  final TextEditingController label;
  final TextEditingController details;
  final TextEditingController minimum;
  final TextEditingController maximum;
  final List<TextEditingController> options;
  final Map<TextEditingController, String> optionIds = {};
  final List<_EditorQuestionDraft> branchQuestions = [];
  bool required;
  bool branchEnabled;
  String? branchOptionId;
  bool branchExpectedYesNo = true;
  _DateRule dateRule = _DateRule.free;
  DateTime from = DateTime(2026, 8, 1);
  DateTime until = DateTime(2026, 8, 31);

  String optionLabel(String id) => options.firstWhere((option) => optionIds[option] == id).text;

  void replaceOptions(List<FormOption> values) {
    for (final option in options) {
      option.dispose();
    }
    options.clear();
    optionIds.clear();
    for (final value in values) {
      final controller = TextEditingController(text: value.label);
      options.add(controller);
      optionIds[controller] = value.id;
    }
  }

  _EditorQuestionDraft copy({
    required String id,
    Map<String, String> itemIdMap = const {},
    Map<String, String> optionIdMap = const {},
  }) {
    final subtree = _flattenQuestions([this]).toList();
    final copiedItemIds = {
      ...itemIdMap,
      for (final question in subtree)
        question.id: itemIdMap[question.id] ?? (question == this ? id : _newRequestId()),
      this.id: id,
    };
    final copiedOptionIds = {
      ...optionIdMap,
      for (final question in subtree)
        for (var index = 0; index < question.options.length; index++)
          question.optionIds[question.options[index]]!:
              optionIdMap[question.optionIds[question.options[index]]!] ??
              '${copiedItemIds[question.id]}-option-$index',
    };
    final value = _EditorQuestionDraft(
      id: id,
      kind: kind,
      label: '${label.text} — cópia',
      required: required,
      branchEnabled: branchEnabled,
      loadedConfig: loadedConfig,
      loadedConditions: [
        for (final condition in loadedConditions)
          switch (condition.kind) {
            FormConditionKind.yesNo => FormCondition.yesNo(
              sourceItemId: copiedItemIds[condition.sourceItemId] ?? condition.sourceItemId,
              expected: condition.expectedYesNo!,
            ),
            FormConditionKind.choice => FormCondition.choice(
              sourceItemId: copiedItemIds[condition.sourceItemId] ?? condition.sourceItemId,
              optionIds: {
                for (final optionId in condition.optionIds) copiedOptionIds[optionId] ?? optionId,
              },
            ),
          },
      ],
    );
    value
      ..dateRule = dateRule
      ..from = from
      ..until = until
      ..details.text = details.text
      ..minimum.text = minimum.text
      ..maximum.text = maximum.text;
    value.replaceOptions([
      for (var index = 0; index < options.length; index++)
        FormOption(
          id: copiedOptionIds[optionIds[options[index]]!]!,
          label: options[index].text,
          position: index,
        ),
    ]);
    value.branchQuestions.addAll([
      for (var index = 0; index < branchQuestions.length; index++)
        branchQuestions[index].copy(
          id: copiedItemIds[branchQuestions[index].id] ?? _newRequestId(),
          itemIdMap: copiedItemIds,
          optionIdMap: copiedOptionIds,
        ),
    ]);
    return value;
  }

  void dispose() {
    label.dispose();
    details.dispose();
    minimum.dispose();
    maximum.dispose();
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
    required this.onReorder,
  });

  final bool compact;
  final List<_EditorSectionDraft> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValueChanged<int> onMove;
  final void Function(int from, int to) onReorder;

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
          ReorderableListView.builder(
            key: const Key('forms-editor-section-reorder-list'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: sections.length,
            onReorderItem: onReorder,
            itemBuilder: (context, index) => Padding(
              key: ValueKey(sections[index].id),
              padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
              child: Semantics(
                button: true,
                selected: index == selectedIndex,
                label:
                    '${sections[index].title}, ${_flattenQuestions(sections[index].questions).length} perguntas',
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
                      ReorderableDragStartListener(
                        index: index,
                        child: const Tooltip(
                          message: 'Arrastar seção',
                          child: Icon(Icons.drag_indicator_rounded),
                        ),
                      ),
                      const SizedBox(width: CoeloSpacing.space2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sections[index].title),
                            Text(
                              '${_flattenQuestions(sections[index].questions).length} perguntas',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
    super.key,
    required this.index,
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
    this.canDrag = true,
    this.branchPanel,
  });

  final int index;
  final _EditorQuestionDraft question;
  final bool expanded;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onToggle;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback? onMoveToSection;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final bool canDrag;
  final Widget? branchPanel;

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
                    if (widget.canDrag)
                      ReorderableDragStartListener(
                        index: widget.index,
                        child: const Tooltip(
                          message: 'Arrastar pergunta',
                          child: Icon(Icons.drag_indicator_rounded),
                        ),
                      ),
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
          if (!widget.expanded && widget.branchPanel != null)
            Padding(padding: const EdgeInsets.all(CoeloSpacing.space3), child: widget.branchPanel),
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
      if (widget.question.kind == FormItemKind.information ||
          widget.question.details.text.isNotEmpty) ...[
        const SizedBox(height: CoeloSpacing.space3),
        CoeloFormTextField(
          controller: widget.question.details,
          labelText: widget.question.kind == FormItemKind.information
              ? 'Detalhes do bloco'
              : 'Ajuda da pergunta',
          prefixIcon: Icons.notes_rounded,
          onChanged: (_) => widget.onChanged(),
        ),
      ],
      if (_isNumericKind(widget.question.kind)) ...[
        const SizedBox(height: CoeloSpacing.space3),
        LayoutBuilder(
          builder: (context, constraints) {
            final minimum = CoeloFormTextField(
              controller: widget.question.minimum,
              labelText: widget.question.kind == FormItemKind.money ? 'Valor mínimo' : 'Mínimo',
              prefixIcon: Icons.vertical_align_bottom_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              onChanged: (_) => widget.onChanged(),
            );
            final maximum = CoeloFormTextField(
              controller: widget.question.maximum,
              labelText: widget.question.kind == FormItemKind.money ? 'Valor máximo' : 'Máximo',
              prefixIcon: Icons.vertical_align_top_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              onChanged: (_) => widget.onChanged(),
            );
            if (constraints.maxWidth < 520) {
              return Column(
                children: [
                  minimum,
                  const SizedBox(height: CoeloSpacing.space3),
                  maximum,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: minimum),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(child: maximum),
              ],
            );
          },
        ),
      ],
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
        ReorderableListView.builder(
          key: ValueKey('forms-editor-options-${widget.question.id}'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.question.options.length,
          onReorderItem: (from, to) {
            setState(() {
              final option = widget.question.options.removeAt(from);
              widget.question.options.insert(to, option);
            });
            widget.onChanged();
          },
          itemBuilder: (context, index) => Padding(
            key: ObjectKey(widget.question.options[index]),
            padding: EdgeInsets.only(
              bottom: index < widget.question.options.length - 1 ? CoeloSpacing.space2 : 0,
            ),
            child: CoeloFormTextField(
              controller: widget.question.options[index],
              labelText: 'Opção ${index + 1}',
              prefixIcon: Icons.radio_button_unchecked_rounded,
              onChanged: (_) => widget.onChanged(),
            ),
          ),
        ),
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
        if (widget.branchPanel != null) ...[
          const SizedBox(height: CoeloSpacing.space3),
          widget.branchPanel!,
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
  const _BranchPanel({
    required this.question,
    required this.onAdd,
    required this.onDelete,
    this.children,
    this.triggerSelector,
  });

  final _EditorQuestionDraft question;
  final VoidCallback? onAdd;
  final ValueChanged<int> onDelete;
  final Widget? children;
  final Widget? triggerSelector;

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
            question.kind == FormItemKind.yesNo ? 'Ramos por resposta' : 'Por opção selecionada',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: CoeloSpacing.space2),
          const Text('Perguntas do ramo permanecem vinculadas a esta resposta.'),
          if (triggerSelector != null) ...[
            const SizedBox(height: CoeloSpacing.space3),
            triggerSelector!,
          ],
          if (children != null)
            children!
          else if (question.branchQuestions.isNotEmpty) ...[
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

bool _isNumericKind(FormItemKind kind) =>
    kind == FormItemKind.integer || kind == FormItemKind.decimal || kind == FormItemKind.money;

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
