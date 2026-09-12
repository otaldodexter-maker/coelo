import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../data/development_forms_api.dart';
import '../../data/forms_anonymous_edit_secret_store.dart';
import 'forms_gallery_answer_field.dart';

enum FormResponseAutosaveState { initial, changed, saving, saved, conflict, failure }

final class FormResponsePage extends StatefulWidget {
  const FormResponsePage({
    this.api,
    this.occurrenceId,
    this.mediaSession,
    this.mediaReader,
    this.anonymousEditSecrets,
    super.key,
  }) : development = false,
       anonymous = false,
       secretLost = false,
       failSubmission = false,
       initialAutosaveState = FormResponseAutosaveState.initial,
       formId = null;

  const FormResponsePage.development({
    this.anonymous = false,
    this.secretLost = false,
    this.failSubmission = false,
    this.initialAutosaveState = FormResponseAutosaveState.initial,
    this.formId,
    super.key,
  }) : development = true,
       api = null,
       mediaSession = null,
       mediaReader = null,
       anonymousEditSecrets = null,
       occurrenceId = null;

  final bool development;
  final FormsApi? api;
  final MediaSession? mediaSession;
  final MediaReader? mediaReader;
  final FormsAnonymousEditSecretStore? anonymousEditSecrets;
  final String? occurrenceId;
  final bool anonymous;
  final bool secretLost;
  final bool failSubmission;
  final FormResponseAutosaveState initialAutosaveState;
  final String? formId;

  @override
  State<FormResponsePage> createState() => _FormResponsePageState();
}

final class _FormResponsePageState extends State<FormResponsePage> {
  final _answer = TextEditingController();
  bool _review = false;
  bool _submitted = false;
  bool _failed = false;
  bool _uploadCanceled = false;
  late FormResponseAutosaveState _autosaveState = widget.initialAutosaveState;
  Timer? _savingTimer;
  Timer? _savedTimer;

  @override
  void initState() {
    super.initState();
    _answer.addListener(_handleAnswerChanged);
  }

  @override
  void dispose() {
    _savingTimer?.cancel();
    _savedTimer?.cancel();
    _answer.removeListener(_handleAnswerChanged);
    _answer.dispose();
    super.dispose();
  }

  void _handleAnswerChanged() {
    if (!widget.development) return;
    _savingTimer?.cancel();
    _savedTimer?.cancel();
    setState(() => _autosaveState = FormResponseAutosaveState.changed);
    _savingTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _autosaveState = FormResponseAutosaveState.saving);
      _savedTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _autosaveState = FormResponseAutosaveState.saved);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.development) {
      return _ProductionFormResponse(
        api: widget.api,
        occurrenceId: widget.occurrenceId,
        mediaSession: widget.mediaSession,
        mediaReader: widget.mediaReader,
        anonymousEditSecrets: widget.anonymousEditSecrets,
      );
    }
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space6
              : CoeloSpacing.space4;
          return ListView(
            padding: EdgeInsets.fromLTRB(inset, CoeloSpacing.space5, inset, CoeloSpacing.space8),
            children: [
              Text(
                widget.development
                    ? developmentFormTitle(widget.formId, fallback: 'Pesquisa das famílias')
                    : 'Formulário sem dados disponíveis',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: CoeloSpacing.space1),
              Text(
                widget.development
                    ? (widget.anonymous ? 'Resposta anônima' : 'Resposta identificada')
                    : 'Identidade indisponível',
              ),
              const SizedBox(height: CoeloSpacing.space4),
              if (widget.anonymous && widget.secretLost)
                const CoeloStatePanel(
                  icon: Icons.key_off_outlined,
                  title: 'Edição irrecuperável',
                  message:
                      'O segredo anônimo foi perdido. A identidade e a edição desta resposta não podem ser recuperadas.',
                )
              else if (_submitted)
                const CoeloStatePanel(
                  icon: Icons.task_alt_rounded,
                  title: 'Resposta enviada nesta demonstração',
                  message:
                      'Este sucesso existe apenas na fixture local. Nenhuma persistência remota foi realizada.',
                )
              else if (_review)
                _buildReview(context)
              else
                _buildForm(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Icon(Icons.history_rounded),
          const SizedBox(width: CoeloSpacing.space2),
          Text('Rascunho retomado', style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space3),
      TextFormField(
        controller: _answer,
        minLines: 4,
        maxLines: 8,
        enabled: widget.development,
        decoration: const InputDecoration(
          labelText: 'Sua resposta',
          hintText: 'Escreva sua contribuição',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: CoeloSpacing.space3),
      _AutosaveStates(available: widget.development, state: _autosaveState),
      const SizedBox(height: CoeloSpacing.space5),
      _ResponseUploads(
        available: widget.development,
        canceled: _uploadCanceled,
        onCancel: () => setState(() => _uploadCanceled = true),
      ),
      const SizedBox(height: CoeloSpacing.space5),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: widget.development
              ? () => setState(() {
                  _review = true;
                  _failed = false;
                })
              : null,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Revisar resposta'),
        ),
      ),
    ],
  );

  Widget _buildReview(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Revisão da resposta', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: CoeloSpacing.space3),
      CoeloAdminInteractiveCard(
        semanticLabel: 'Resposta: ${_answer.text}',
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Text(_answer.text.isEmpty ? 'Sem resposta informada' : _answer.text),
        ),
      ),
      if (_failed) ...[
        const SizedBox(height: CoeloSpacing.space3),
        const CoeloStatePanel(
          icon: Icons.error_outline_rounded,
          title: 'A resposta não foi enviada',
          message: 'Os dados locais foram preservados. Revise e tente novamente.',
        ),
      ],
      const SizedBox(height: CoeloSpacing.space4),
      Wrap(
        alignment: WrapAlignment.end,
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: [
          OutlinedButton(
            onPressed: () => setState(() => _review = false),
            child: const Text('Voltar e editar'),
          ),
          FilledButton(
            onPressed: () => setState(() {
              if (widget.failSubmission) {
                _failed = true;
              } else {
                _submitted = true;
              }
            }),
            child: const Text('Enviar resposta'),
          ),
        ],
      ),
    ],
  );
}

enum _ProductionResponseState { loading, unavailable, unauthorized, error, content, submitted }

final class _ProductionFormResponse extends StatefulWidget {
  const _ProductionFormResponse({
    required this.api,
    required this.occurrenceId,
    required this.mediaSession,
    required this.mediaReader,
    required this.anonymousEditSecrets,
  });

  final FormsApi? api;
  final MediaSession? mediaSession;
  final MediaReader? mediaReader;
  final FormsAnonymousEditSecretStore? anonymousEditSecrets;
  final String? occurrenceId;

  @override
  State<_ProductionFormResponse> createState() => _ProductionFormResponseState();
}

enum _ResponseCommandKind { save, submit, edit }

final class _ProductionFormResponseState extends State<_ProductionFormResponse> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, FormAnswer> _answers = {};
  _ProductionResponseState _state = _ProductionResponseState.loading;
  FormOccurrenceForResponse? _occurrence;
  FormResponseDraft? _draft;
  String? _editSecret;
  MediaReader? _anonymousImageReader;
  String? _message;
  bool _review = false;
  bool _saving = false;
  int _loadGeneration = 0;
  int _answerRevision = 0;
  int _savedAnswerRevision = 0;
  Timer? _autosaveTimer;
  bool _autosavePaused = false;
  final _invalidAnswerReasons = <String, String>{};
  String? _activeSectionId;
  final _sectionFocus = <String, FocusNode>{};
  final _busyMediaItems = <String>{};
  ({_ResponseCommandKind kind, FormCommand<FormResponseDraftPayload> command, int answerRevision})?
  _pendingCommand;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ProductionFormResponse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.api, widget.api) ||
        oldWidget.occurrenceId != widget.occurrenceId ||
        !identical(oldWidget.mediaSession, widget.mediaSession) ||
        !identical(oldWidget.anonymousEditSecrets, widget.anonymousEditSecrets)) {
      _load();
    }
  }

  bool _isCurrent(int generation) => mounted && generation == _loadGeneration;

  VoidCallback _currentAction(VoidCallback action) {
    final generation = _loadGeneration;
    return () {
      if (_isCurrent(generation)) action();
    };
  }

  @override
  void dispose() {
    _editSecret = null;
    _anonymousImageReader = null;
    _autosaveTimer?.cancel();
    for (final node in _sectionFocus.values) {
      node.dispose();
    }
    _loadGeneration++;
    super.dispose();
  }

  Future<void> _load() async {
    _autosaveTimer?.cancel();
    for (final node in _sectionFocus.values) {
      node.dispose();
    }
    _sectionFocus.clear();
    final generation = ++_loadGeneration;
    final api = widget.api;
    final occurrenceId = widget.occurrenceId;
    setState(() {
      _state = _ProductionResponseState.loading;
      _occurrence = null;
      _draft = null;
      _editSecret = null;
      _anonymousImageReader = null;
      _answers.clear();
      _message = null;
      _review = false;
      _saving = false;
      _pendingCommand = null;
      _answerRevision = 0;
      _savedAnswerRevision = 0;
      _autosavePaused = false;
      _invalidAnswerReasons.clear();
      _activeSectionId = null;
      _busyMediaItems.clear();
    });
    if (api == null || occurrenceId == null || occurrenceId.isEmpty) {
      setState(() => _state = _ProductionResponseState.unavailable);
      return;
    }
    try {
      final occurrence = await api.getOccurrenceForResponse(occurrenceId);
      if (!_isCurrent(generation)) return;
      if (occurrence.draft == null && !occurrence.canEdit) {
        if (mounted) {
          setState(() {
            _message = 'A fonte autorizada não permite iniciar ou editar esta resposta.';
            _state = _ProductionResponseState.unauthorized;
          });
        }
        return;
      }
      String? editSecret;
      if (occurrence.identityMode == FormIdentityMode.anonymous) {
        final store = widget.anonymousEditSecrets;
        if (store == null) throw const FormsAnonymousEditSecretException();
        editSecret = await store.loadOrCreate(occurrence.occurrence.id);
        if (!_isCurrent(generation)) return;
      }
      final draft =
          (occurrence.identityMode == FormIdentityMode.identified ? occurrence.draft : null) ??
          await api.openResponseDraft(
            FormCommand(
              requestId: _newResponseRequestId(),
              expectedVersion: 0,
              payload: FormOpenResponseDraftPayload(
                occurrenceId: occurrence.occurrence.id,
                participationId: occurrence.participationId,
                identityMode: occurrence.identityMode,
                editSecret: editSecret,
              ),
            ),
          );
      if (!_isCurrent(generation)) return;
      final anonymousImageReader = editSecret != null && api is FormsAnonymousImageApi
          ? (api as FormsAnonymousImageApi).anonymousImageReader(editSecret: editSecret)
          : null;
      setState(() {
        _occurrence = occurrence;
        _draft = draft;
        _editSecret = editSecret;
        _anonymousImageReader = anonymousImageReader;
        _answers
          ..clear()
          ..addAll(draft.answers);
        _pruneHiddenAnswers();
        _state = draft.status == FormResponseDraftStatus.submitted
            ? _ProductionResponseState.submitted
            : occurrence.canEdit
            ? _ProductionResponseState.content
            : _ProductionResponseState.unauthorized;
        if (_state == _ProductionResponseState.unauthorized) {
          _message = 'A fonte autorizada não permite editar esta resposta.';
        }
      });
    } on FormsAnonymousEditSecretException catch (error) {
      if (_isCurrent(generation)) {
        setState(() {
          _message = error.message;
          _state = _ProductionResponseState.error;
        });
      }
    } on FormApiException catch (error) {
      if (_isCurrent(generation)) {
        setState(() {
          _message = error.message;
          _state = error.kind == FormApiFailureKind.unauthorized
              ? _ProductionResponseState.unauthorized
              : _ProductionResponseState.error;
        });
      }
    } on Object {
      if (_isCurrent(generation)) {
        setState(() {
          _message = 'Não foi possível carregar esta resposta agora.';
          _state = _ProductionResponseState.error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final inset = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space6
            : CoeloSpacing.space4;
        return ListView(
          key: const Key('form-response-production-scroll'),
          padding: EdgeInsets.fromLTRB(inset, CoeloSpacing.space5, inset, CoeloSpacing.space8),
          children: [
            Text('Responder formulário', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: CoeloSpacing.space3),
            switch (_state) {
              _ProductionResponseState.loading => const Center(child: CircularProgressIndicator()),
              _ProductionResponseState.unavailable => const CoeloStatePanel(
                key: Key('form-response-unavailable'),
                icon: Icons.lock_outline_rounded,
                title: 'Resposta indisponível',
                message: 'Esta rota precisa de uma ocorrência autorizada para abrir uma resposta.',
              ),
              _ProductionResponseState.unauthorized => CoeloStatePanel(
                icon: Icons.lock_outline_rounded,
                title: 'Acesso não autorizado',
                message: _message ?? 'Você não tem acesso a esta ocorrência.',
              ),
              _ProductionResponseState.error => CoeloStatePanel(
                icon: Icons.error_outline_rounded,
                title: 'Não foi possível abrir a resposta',
                message: _message ?? 'Tente novamente mais tarde.',
                actionLabel: 'Tentar novamente',
                onAction: _currentAction(_load),
              ),
              _ProductionResponseState.submitted => _submittedView(context),
              _ProductionResponseState.content => _responseForm(context),
            },
          ],
        );
      },
    ),
  );

  Widget _submittedView(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CoeloStatePanel(
        icon: Icons.task_alt_rounded,
        title: 'Resposta enviada',
        message: 'Esta resposta foi confirmada pela fonte autorizada.',
        actionLabel: _occurrence!.canEdit ? 'Editar resposta' : null,
        onAction: _occurrence!.canEdit && !_saving ? _currentAction(_editSubmittedResponse) : null,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      _answerSummary(context),
      if (_message case final message?) ...[
        const SizedBox(height: CoeloSpacing.space3),
        Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    ],
  );

  Widget _responseForm(BuildContext context) {
    final occurrence = _occurrence!;
    final visibleItemIds = _visibleItemIds;
    final sections = _presentedSections;
    final sectionIndex = sections.indexWhere((section) => section.id == _activeSectionId);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(occurrence.version.formId, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            occurrence.identityMode == FormIdentityMode.anonymous
                ? 'Resposta anônima'
                : 'Resposta identificada',
          ),
          if (occurrence.identityMode == FormIdentityMode.anonymous) ...[
            const SizedBox(height: CoeloSpacing.space2),
            const Text(
              'A edição desta resposta fica neste dispositivo. Se os dados locais forem apagados, '
              'a edição não poderá ser recuperada.',
            ),
          ],
          const SizedBox(height: CoeloSpacing.space5),
          if (sections.isNotEmpty) ...[
            LinearProgressIndicator(
              value: (sectionIndex + 1) / sections.length,
              semanticsLabel:
                  'Progresso das seções do formulário: seção ${sectionIndex + 1} de ${sections.length}',
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Text('Seção ${sectionIndex + 1} de ${sections.length}'),
            const SizedBox(height: CoeloSpacing.space4),
          ],
          for (final section in occurrence.version.sections)
            Offstage(
              key: ValueKey('response-section-${section.id}'),
              offstage: section.id != _activeSectionId,
              child: ExcludeFocus(
                excluding: section.id != _activeSectionId,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Focus(
                      focusNode: _sectionFocus.putIfAbsent(section.id, () => FocusNode()),
                      child: Semantics(
                        header: true,
                        child: Text(section.title, style: Theme.of(context).textTheme.titleLarge),
                      ),
                    ),
                    if (section.description case final description?) ...[
                      const SizedBox(height: CoeloSpacing.space1),
                      Text(description),
                    ],
                    const SizedBox(height: CoeloSpacing.space3),
                    for (final item in section.items)
                      if (visibleItemIds.contains(item.id)) ...[
                        _itemField(context, item),
                        const SizedBox(height: CoeloSpacing.space4),
                      ],
                  ],
                ),
              ),
            ),
          if (sections.length > 1) ...[
            Wrap(
              spacing: CoeloSpacing.space2,
              runSpacing: CoeloSpacing.space2,
              children: [
                OutlinedButton(
                  key: const Key('form-response-previous-section'),
                  onPressed: sectionIndex > 0
                      ? _currentAction(() => _selectSection(sections[sectionIndex - 1].id))
                      : null,
                  child: const Text('Seção anterior'),
                ),
                OutlinedButton(
                  key: const Key('form-response-next-section'),
                  onPressed: sectionIndex >= 0 && sectionIndex < sections.length - 1
                      ? _currentAction(() => _selectSection(sections[sectionIndex + 1].id))
                      : null,
                  child: const Text('Próxima seção'),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
          ],
          if (_message case final message?) ...[
            Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: CoeloSpacing.space3),
          ],
          Wrap(
            alignment: WrapAlignment.end,
            spacing: CoeloSpacing.space2,
            runSpacing: CoeloSpacing.space2,
            children: [
              if (_draft?.status == FormResponseDraftStatus.submitted)
                OutlinedButton(
                  onPressed: _saving || _pendingCommand != null
                      ? null
                      : _currentAction(_cancelSubmittedEdit),
                  child: const Text('Cancelar edição'),
                )
              else
                OutlinedButton(
                  key: const Key('form-response-save-draft'),
                  onPressed:
                      _saving ||
                          (_pendingCommand != null &&
                              _pendingCommand!.kind != _ResponseCommandKind.save)
                      ? null
                      : _currentAction(_saveDraft),
                  child: const Text('Salvar rascunho'),
                ),
              FilledButton.icon(
                key: const Key('form-response-review'),
                onPressed: _saving || _pendingCommand != null
                    ? null
                    : _currentAction(_reviewResponse),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Revisar resposta'),
              ),
            ],
          ),
          if (_review) ...[
            const SizedBox(height: CoeloSpacing.space5),
            Text('Revisão da resposta', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: CoeloSpacing.space3),
            _answerSummary(context),
            const SizedBox(height: CoeloSpacing.space4),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: CoeloSpacing.space2,
              runSpacing: CoeloSpacing.space2,
              children: [
                OutlinedButton(
                  onPressed: _saving || _pendingCommand != null
                      ? null
                      : _currentAction(() {
                          setState(() => _review = false);
                          _scheduleAutosave();
                        }),
                  child: const Text('Voltar e editar'),
                ),
                FilledButton(
                  key: const Key('form-response-submit'),
                  onPressed:
                      _saving ||
                          (_pendingCommand != null && _pendingCommand!.kind != _confirmationKind)
                      ? null
                      : _currentAction(_submit),
                  child: Text(
                    _saving
                        ? 'Enviando…'
                        : _confirmationKind == _ResponseCommandKind.edit
                        ? 'Confirmar alterações'
                        : 'Enviar resposta',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _answerSummary(BuildContext context) => CoeloAdminInteractiveCard(
    semanticLabel: 'Resumo das respostas',
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final section in _occurrence!.version.sections)
            for (final item in section.items)
              if (item.kind != FormItemKind.information && _isVisible(item))
                if (_answers[item.id] case final FormAnswer answer)
                  Padding(
                    padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
                    child: Text('${item.label}: ${_answerLabel(item, answer)}'),
                  ),
        ],
      ),
    ),
  );

  Widget _itemField(BuildContext context, FormItem item) {
    final generation = _loadGeneration;
    void update(FormAnswer? answer) {
      if (_isCurrent(generation)) _setAnswer(item, answer);
    }

    if (item.kind == FormItemKind.information) {
      return CoeloStatePanel(
        icon: Icons.info_outline_rounded,
        title: item.label,
        message: item.helpText ?? '',
      );
    }
    final heading = Text(
      '${item.label}${item.isRequired ? ' *' : ''}',
      style: Theme.of(context).textTheme.titleMedium,
    );
    if (_unanswerableConfiguration(item) case final issue?) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: CoeloSpacing.space2),
          CoeloStatePanel(
            icon: Icons.info_outline_rounded,
            title: 'Pergunta indisponível',
            message: item.isRequired
                ? issue
                : '$issue Você pode deixar esta pergunta sem resposta.',
          ),
          if (_hasAnswer(item))
            TextButton(onPressed: () => update(null), child: const Text('Limpar resposta')),
        ],
      );
    }
    // O limite autorado de selecoes e regra do formulario e precisa ser dito
    // ANTES da escolha, junto do texto de ajuda: descobrir a regra ao ser
    // recusado e o defeito que esta correcao fecha.
    final selectionHint = item.kind == FormItemKind.multipleChoice
        ? FormSelectionLimits.hint(item.config)
        : null;
    final authoredHelp = item.helpText;
    final help = switch ((authoredHelp, selectionHint)) {
      (null || '', final hint) => hint,
      (final text?, null) => text,
      (final text?, final hint?) => '$text\n$hint',
    };
    final field = switch (item.kind) {
      FormItemKind.shortText => TextFormField(
        key: Key('form-response-item-${item.id}'),
        initialValue: _textValue(item.id),
        minLines: 2,
        maxLines: 6,
        onChanged: (value) {
          if (_isCurrent(generation)) _setTextAnswer(item, value);
        },
        validator: (_) => _requiredMessage(item),
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      FormItemKind.integer || FormItemKind.decimal || FormItemKind.money => TextFormField(
        key: Key('form-response-item-${item.id}'),
        initialValue: _numberValue(item.id),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (value) {
          if (_isCurrent(generation)) _setNumericAnswer(item, value);
        },
        validator: (_) => _requiredMessage(item),
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      FormItemKind.yesNo => Wrap(
        spacing: CoeloSpacing.space2,
        children: [
          for (final option in [true, false])
            ChoiceChip(
              label: Text(option ? 'Sim' : 'Não'),
              selected: (_answers[item.id]?.value as FormYesNoValue?)?.value == option,
              onSelected: (_) => update(FormAnswer.yesNo(itemId: item.id, value: option)),
            ),
        ],
      ),
      FormItemKind.singleChoice => Wrap(
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: [
          for (final option in item.options)
            ChoiceChip(
              label: Text(option.label),
              selected:
                  (_answers[item.id]?.value as FormChoiceValue?)?.optionIds.contains(option.id) ??
                  false,
              onSelected: (_) =>
                  update(FormAnswer.singleChoice(itemId: item.id, optionId: option.id)),
            ),
        ],
      ),
      // P16 (Decisoes 9, 10 e 12): opcoes fixas do snapshot; Local revogado
      // fica desabilitado com rotulo honesto; obrigatoria sem alternativa
      // valida bloqueia com aviso, sem forcar escolha invalida.
      FormItemKind.location => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_locationBlockingMessage(item) case final blocking?) ...[
            CoeloStatePanel(
              key: Key('form-response-location-blocked-${item.id}'),
              icon: Icons.location_off_outlined,
              title: 'Nenhum local disponível',
              message: blocking,
            ),
            const SizedBox(height: CoeloSpacing.space2),
          ],
          Wrap(
            spacing: CoeloSpacing.space2,
            runSpacing: CoeloSpacing.space2,
            children: [
              for (final option in item.options)
                ChoiceChip(
                  key: Key('form-response-location-${item.id}-${option.id}'),
                  label: Text(
                    option.isSelectable ? option.label : '${option.label} (indisponível)',
                  ),
                  selected:
                      (_answers[item.id]?.value as FormChoiceValue?)?.optionIds.contains(
                        option.id,
                      ) ??
                      false,
                  onSelected: option.isSelectable
                      ? (_) => update(FormAnswer.location(itemId: item.id, optionId: option.id))
                      : null,
                ),
            ],
          ),
        ],
      ),
      FormItemKind.multipleChoice => Wrap(
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: [
          for (final option in item.options)
            FilterChip(
              label: Text(option.label),
              selected:
                  (_answers[item.id]?.value as FormChoiceValue?)?.optionIds.contains(option.id) ??
                  false,
              onSelected: (selected) {
                if (!_isCurrent(generation)) return;
                final selectedIds = {...?(_answers[item.id]?.value as FormChoiceValue?)?.optionIds};
                selected ? selectedIds.add(option.id) : selectedIds.remove(option.id);
                // Recusar a marcacao a mais, em vez de aceitar e deixar o
                // servidor recusar o envio inteiro. Desmarcar nunca e recusado:
                // e o unico caminho de volta para uma contagem valida.
                if (selected) {
                  final reason = FormSelectionLimits.violation(item.config, selectedIds.length);
                  if (reason != null &&
                      selectedIds.length > FormSelectionLimits.maximum(item.config)) {
                    _refuseAnswer(item, reason);
                    return;
                  }
                }
                _invalidAnswerReasons.remove(item.id);
                update(
                  selectedIds.isEmpty
                      ? null
                      : FormAnswer.multipleChoice(itemId: item.id, optionIds: selectedIds),
                );
              },
            ),
        ],
      ),
      FormItemKind.scale => Wrap(
        spacing: CoeloSpacing.space2,
        children: [
          // Os padroes espelham os do servidor, coalesce(scale_min, 1) e
          // coalesce(scale_max, 10). Comecar em zero oferecia um valor que o
          // servidor sempre recusaria numa escala sem minimo declarado.
          for (
            var value = item.config.scaleMin ?? 1;
            value <= (item.config.scaleMax ?? 10);
            value++
          )
            ChoiceChip(
              label: Text('$value'),
              selected: (_answers[item.id]?.value as FormScaleValue?)?.value == value,
              onSelected: (_) => update(FormAnswer.scale(itemId: item.id, value: value)),
            ),
        ],
      ),
      FormItemKind.date => OutlinedButton.icon(
        onPressed: () {
          if (_isCurrent(generation)) _pickDate(item);
        },
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text(_dateValue(item.id) ?? 'Selecionar data'),
      ),
      FormItemKind.gallery
          when widget.mediaSession != null &&
              !widget.mediaSession!.isInvalidated &&
              _galleryContextAvailable =>
        FormsGalleryAnswerField(
          key: ValueKey('gallery-${widget.occurrenceId}-${item.id}-$_loadGeneration'),
          api: widget.api!,
          session: widget.mediaSession!,
          reader: _editSecret == null ? widget.mediaReader : _anonymousImageReader,
          editSecret: _editSecret,
          occurrenceId: widget.occurrenceId!,
          item: item,
          assetIds: (_answers[item.id]?.value as FormAssetValue?)?.assetIds ?? const [],
          enabled: !_saving && _pendingCommand == null && _occurrence?.canEdit == true,
          onChanged: (ids) =>
              update(ids.isEmpty ? null : FormAnswer.gallery(itemId: item.id, assetIds: ids)),
          onBusyChanged: (busy) {
            if (!_isCurrent(generation)) return;
            setState(() {
              busy ? _busyMediaItems.add(item.id) : _busyMediaItems.remove(item.id);
            });
            if (busy) {
              _autosaveTimer?.cancel();
            } else {
              _scheduleAutosave();
            }
          },
        ),
      FormItemKind.photo || FormItemKind.gallery => const CoeloStatePanel(
        icon: Icons.lock_outline_rounded,
        title: 'Anexo indisponível',
        message: 'O envio protegido de arquivos ainda não está disponível nesta superfície.',
      ),
      FormItemKind.information => const SizedBox.shrink(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading,
        if (help != null && help.isNotEmpty) ...[
          const SizedBox(height: CoeloSpacing.space1),
          Text(help),
        ],
        const SizedBox(height: CoeloSpacing.space2),
        field,
      ],
    );
  }

  Set<String> get _visibleItemIds {
    final items =
        _occurrence?.version.sections.expand((section) => section.items).toList() ?? <FormItem>[];
    final visible = {
      for (final item in items)
        if (item.conditions.isEmpty) item.id,
    };
    var changed = true;
    // Grow only from visible sources: hidden ancestors and malformed cycles
    // cannot activate a branch using residual answers from an earlier state.
    while (changed) {
      changed = false;
      final sourceAnswers = {
        for (final item in items)
          if (visible.contains(item.id) &&
              item.kind != FormItemKind.information &&
              _answers.containsKey(item.id))
            item.id: _answers[item.id]!,
      };
      for (final item in items) {
        if (!visible.contains(item.id) &&
            const FormVisibilityEvaluator().isVisible(
              conditions: item.conditions,
              answers: sourceAnswers,
            )) {
          visible.add(item.id);
          changed = true;
        }
      }
    }
    return visible;
  }

  bool _isVisible(FormItem item) => _visibleItemIds.contains(item.id);

  List<FormSection> get _presentedSections {
    final visible = _visibleItemIds;
    return [
      for (final section in _occurrence?.version.sections ?? const <FormSection>[])
        if (section.items.isEmpty || section.items.any((item) => visible.contains(item.id)))
          section,
    ];
  }

  void _selectSection(String id) {
    if (!_presentedSections.any((section) => section.id == id)) return;
    setState(() => _activeSectionId = id);
    _focusSection(id);
  }

  void _focusSection(String id) {
    final generation = _loadGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isCurrent(generation) || _activeSectionId != id) return;
      final node = _sectionFocus[id];
      node?.requestFocus();
      final target = node?.context;
      if (target != null) Scrollable.ensureVisible(target);
    });
  }

  void _pruneHiddenAnswers() {
    final visible = _visibleItemIds;
    _busyMediaItems.removeWhere((id) => !visible.contains(id));
    _answers.removeWhere((id, _) => !visible.contains(id));
    _invalidAnswerReasons.removeWhere((id, _) => !visible.contains(id));
    final sections = _presentedSections;
    if (!sections.any((section) => section.id == _activeSectionId)) {
      final hadActiveSection = _activeSectionId != null;
      _activeSectionId = sections.firstOrNull?.id;
      if (hadActiveSection && _activeSectionId != null) _focusSection(_activeSectionId!);
    }
  }

  bool _hasAnswer(FormItem item) => switch (_answers[item.id]?.value) {
    null => false,
    FormShortTextValue(:final value) => value.trim().isNotEmpty,
    FormChoiceValue(:final optionIds) => optionIds.isNotEmpty,
    FormAssetValue(:final assetIds) => assetIds.isNotEmpty,
    _ => true,
  };

  String? _requiredMessage(FormItem item) =>
      item.isRequired && !_hasAnswer(item) ? 'Esta resposta é obrigatória.' : null;

  void _setAnswer(FormItem item, FormAnswer? answer) {
    if (!mounted || _state != _ProductionResponseState.content || _occurrence?.canEdit != true) {
      return;
    }
    final before = _answersFingerprint();
    if (answer == null) {
      _answers.remove(item.id);
    } else {
      _answers[item.id] = answer;
    }
    _pruneHiddenAnswers();
    if (before == _answersFingerprint()) return;
    setState(() {
      _answerRevision++;
      if (_pendingCommand?.kind != _ResponseCommandKind.submit &&
          _pendingCommand?.kind != _ResponseCommandKind.edit) {
        _review = false;
      }
      if (!_autosavePaused) _message = 'Alterações ainda não salvas.';
    });
    _scheduleAutosave();
  }

  String _answersFingerprint() => jsonEncode({
    for (final id in _answers.keys.toList()..sort())
      id: FormAnswerDto.fromDomain(_answers[id]!).toJson(),
  });

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    if (_state != _ProductionResponseState.content ||
        _busyMediaItems.isNotEmpty ||
        _occurrence?.canEdit != true ||
        _draft?.status != FormResponseDraftStatus.draft ||
        _saving ||
        _review ||
        _autosavePaused ||
        _invalidAnswerReasons.isNotEmpty ||
        _pendingCommand != null ||
        _answerRevision == _savedAnswerRevision) {
      return;
    }
    final generation = _loadGeneration;
    _autosaveTimer = Timer(const Duration(milliseconds: 800), () {
      if (!_isCurrent(generation) ||
          _review ||
          _autosavePaused ||
          _state != _ProductionResponseState.content ||
          _occurrence?.canEdit != true) {
        return;
      }
      unawaited(_sendDraft(_ResponseCommandKind.save, automatic: true));
    });
  }

  /// One refusal path for every answer that fails its authored limit, so the
  /// draft, the autosave and the submit gate all see the same state.
  void _refuseAnswer(FormItem item, String reason) {
    _autosaveTimer?.cancel();
    setState(() {
      _invalidAnswerReasons[item.id] = reason;
      _answerRevision++;
      if (_pendingCommand?.kind != _ResponseCommandKind.submit) _review = false;
      // The banner names what was refused. Saying "valores numéricos" for a
      // text length would send the person to the wrong field.
      _message = FormNumericLimits.isNumeric(item.kind)
          ? 'Revise os valores numéricos antes de salvar.'
          : 'Revise as respostas antes de salvar.';
    });
  }

  /// Short text shares the same refusal path so an authored maxLength is a real
  /// gate, not only a hint on the field.
  void _setTextAnswer(FormItem item, String raw) {
    if (!mounted || _state != _ProductionResponseState.content || _occurrence?.canEdit != true) {
      return;
    }
    if (FormNumericLimits.textViolation(item.config, raw) case final reason?) {
      _refuseAnswer(item, reason);
      return;
    }
    final repaired = _invalidAnswerReasons.remove(item.id) != null;
    _setAnswer(item, raw.trim().isEmpty ? null : FormAnswer.shortText(itemId: item.id, value: raw));
    if (repaired && !_autosavePaused) {
      setState(() => _message = 'Alterações ainda não salvas.');
      // Repairing back to the stored text leaves the answers identical, so
      // _setAnswer returned early and scheduled nothing. Without this the
      // screen keeps announcing an unsaved change that will never be saved.
      _scheduleAutosave();
    }
  }

  void _setNumericAnswer(FormItem item, String raw) {
    if (!mounted || _state != _ProductionResponseState.content || _occurrence?.canEdit != true) {
      return;
    }
    final value = raw.trim();
    // FormNumericLimits is the single representation: money parses to minor
    // units, so the authored range and the stored answer share one unit.
    final parsed = FormNumericLimits.parse(item.kind, value);
    final reason = value.isEmpty
        ? null
        : parsed == null
        ? 'Revise os valores numéricos antes de salvar.'
        : FormNumericLimits.violation(item.kind, item.config, parsed);
    if (reason != null) {
      _refuseAnswer(item, reason);
      return;
    }
    final repaired = _invalidAnswerReasons.remove(item.id) != null;
    final answer = switch ((item.kind, parsed)) {
      (FormItemKind.integer, final number?) => FormAnswer.integer(
        itemId: item.id,
        value: number.toInt(),
      ),
      (FormItemKind.decimal, final number?) => FormAnswer.decimal(
        itemId: item.id,
        value: number.toDouble(),
      ),
      (FormItemKind.money, final number?) => FormAnswer.money(
        itemId: item.id,
        minorUnits: number.toInt(),
      ),
      _ => null,
    };
    _setAnswer(item, answer);
    if (repaired && !_autosavePaused) {
      setState(() => _message = 'Alterações ainda não salvas.');
    }
    _scheduleAutosave();
  }

  String _textValue(String itemId) => (_answers[itemId]?.value as FormShortTextValue?)?.value ?? '';
  String _numberValue(String itemId) => switch (_answers[itemId]?.value) {
    FormIntegerValue(:final value) => '$value',
    FormDecimalValue(:final value) => '$value',
    // Money is stored in minor units; show it the way the author declared it.
    FormMoneyValue(:final minorUnits) => FormNumericLimits.format(FormItemKind.money, minorUnits),
    _ => '',
  };
  String? _dateValue(String itemId) => switch (_answers[itemId]?.value) {
    FormDateValue(:final value) => _civilDate(value),
    _ => null,
  };

  Future<void> _pickDate(FormItem item) async {
    final generation = _loadGeneration;
    final now = DateTime.now();
    // The author can declare a range and the server refuses a date outside it.
    // Offering 120 years either way let the person pick a date the backend was
    // always going to reject.
    final first = item.config.minDate ?? DateTime(now.year - 120);
    final last = item.config.maxDate ?? DateTime(now.year + 20);
    if (first.isAfter(last)) {
      // O editor recusa intervalo invertido, mas dado legado pode ter. Sem esta
      // guarda showDatePicker estoura na propria afirmacao dele, e mesmo sem
      // estourar nao existe data que o servidor fosse aceitar.
      setState(
        () => _message =
            'Esta pergunta tem um intervalo de datas inválido e não pode ser respondida.',
      );
      return;
    }
    final stored = (_answers[item.id]?.value as FormDateValue?)?.value ?? now;
    // A stored answer can predate a range declared later. showDatePicker
    // asserts the initial date is inside the range, so clamp instead of crash.
    final initial = stored.isBefore(first)
        ? first
        : stored.isAfter(last)
        ? last
        : stored;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (selected != null && _isCurrent(generation)) {
      setState(() => _setAnswer(item, FormAnswer.date(itemId: item.id, value: selected)));
    }
  }

  void _reviewResponse() {
    if (_state != _ProductionResponseState.content ||
        _occurrence?.canEdit != true ||
        _saving ||
        _pendingCommand != null) {
      return;
    }
    if (!_validate()) return;
    _autosaveTimer?.cancel();
    setState(() => _review = true);
  }

  bool _validate() {
    if (_busyMediaItems.isNotEmpty) {
      setState(() => _message = 'Confirme ou descarte o envio de imagem antes de continuar.');
      return false;
    }
    final visibleItemIds = _visibleItemIds;
    for (final section in _presentedSections) {
      for (final item in section.items) {
        if (!visibleItemIds.contains(item.id)) continue;
        final message = _itemValidationMessage(item);
        if (message == null) continue;
        _selectSection(section.id);
        _formKey.currentState?.validate();
        setState(() {
          _review = false;
          _message = message;
        });
        return false;
      }
    }
    final fieldsValid = _formKey.currentState?.validate() ?? false;
    if (fieldsValid) setState(() => _message = null);
    return fieldsValid;
  }

  /// Por que uma pergunta de Local obrigatoria nao pode ser respondida agora,
  /// ou null quando ha ao menos um Local valido (ou a pergunta e opcional).
  String? _locationBlockingMessage(FormItem item) {
    if (item.kind != FormItemKind.location || !item.isRequired) return null;
    if (item.options.any((option) => option.isSelectable)) return null;
    return item.options.isEmpty
        ? 'Esta pergunta obrigatória ainda não tem locais do catálogo da instituição. Não é possível enviar a resposta.'
        : 'Todos os locais desta pergunta obrigatória foram desativados pela instituição. Não é possível enviar a resposta até um local voltar a ficar disponível.';
  }

  String? _itemValidationMessage(FormItem item) {
    if (_unanswerableConfiguration(item) case final issue?) {
      if (item.isRequired || _hasAnswer(item)) return issue;
    }
    if (_invalidAnswerReasons[item.id] case final reason?) return reason;
    if (item.kind == FormItemKind.location) {
      if (_locationBlockingMessage(item) case final blocking?) return blocking;
      final value = _answers[item.id]?.value;
      if (value is FormChoiceValue &&
          item.options.any(
            (option) => value.optionIds.contains(option.id) && !option.isSelectable,
          )) {
        return 'O local escolhido não está mais disponível. Escolha outro local.';
      }
    }
    if (item.kind == FormItemKind.multipleChoice) {
      final value = _answers[item.id]?.value;
      if (value is FormChoiceValue) {
        if (FormSelectionLimits.violation(item.config, value.optionIds.length) case final reason?) {
          return reason;
        }
      }
    }
    if (item.kind == FormItemKind.gallery) {
      final value = _answers[item.id]?.value;
      if (value is FormAssetValue && value.assetIds.isNotEmpty) {
        final minimum = item.config.minImages ?? 1;
        final maximum = item.config.maxImages ?? 5;
        if (value.assetIds.length < minimum || value.assetIds.length > maximum) {
          return 'Esta galeria exige entre $minimum e $maximum imagens.';
        }
      }
    }
    if (!item.isRequired || item.kind == FormItemKind.information) return null;
    if (item.kind == FormItemKind.photo || item.kind == FormItemKind.gallery) {
      final value = _answers[item.id]?.value;
      if (value is FormAssetValue && value.assetIds.isNotEmpty) return null;
      return item.kind == FormItemKind.gallery &&
              widget.mediaSession?.isInvalidated == false &&
              _galleryContextAvailable
          ? 'Adicione uma imagem antes de revisar a resposta.'
          : 'Este formulário exige anexo e o envio protegido ainda não está disponível nesta superfície.';
    }
    return _hasAnswer(item)
        ? null
        : 'Responda às perguntas obrigatórias visíveis antes de revisar.';
  }

  bool get _galleryContextAvailable =>
      _occurrence?.identityMode == FormIdentityMode.identified ||
      (_editSecret != null && _anonymousImageReader != null);

  String? _unanswerableConfiguration(FormItem item) {
    if ((item.kind == FormItemKind.singleChoice || item.kind == FormItemKind.multipleChoice) &&
        item.options.isEmpty) {
      return 'Esta pergunta não tem opções disponíveis e não pode ser respondida.';
    }
    if (item.kind == FormItemKind.scale &&
        (item.config.scaleMin ?? 1) > (item.config.scaleMax ?? 10)) {
      return 'Esta pergunta tem um intervalo de escala inválido e não pode ser respondida.';
    }
    return null;
  }

  Future<void> _saveDraft() => _draft?.status == FormResponseDraftStatus.draft
      ? _sendDraft(_ResponseCommandKind.save)
      : Future.value();

  _ResponseCommandKind get _confirmationKind => _draft?.status == FormResponseDraftStatus.submitted
      ? _ResponseCommandKind.edit
      : _ResponseCommandKind.submit;

  Future<void> _submit() {
    final kind = _confirmationKind;
    if (!_review && _pendingCommand?.kind != kind) return Future.value();
    if (_pendingCommand?.kind != kind && !_validate()) return Future.value();
    return _sendDraft(kind);
  }

  void _editSubmittedResponse() {
    if (_state != _ProductionResponseState.submitted ||
        _occurrence?.canEdit != true ||
        _saving ||
        _pendingCommand != null) {
      return;
    }
    setState(() {
      _state = _ProductionResponseState.content;
      _review = false;
      _message = 'Revise e confirme as alterações para atualizar a resposta enviada.';
    });
  }

  void _cancelSubmittedEdit() {
    if (_draft?.status != FormResponseDraftStatus.submitted || _saving || _pendingCommand != null) {
      return;
    }
    _autosaveTimer?.cancel();
    setState(() {
      _answers
        ..clear()
        ..addAll(_draft!.answers);
      _invalidAnswerReasons.clear();
      _answerRevision = _savedAnswerRevision;
      _review = false;
      _message = null;
      _state = _ProductionResponseState.submitted;
    });
  }

  Future<void> _sendDraft(_ResponseCommandKind kind, {bool automatic = false}) async {
    _autosaveTimer?.cancel();
    if (_busyMediaItems.isNotEmpty) {
      setState(() => _message = 'Confirme ou descarte o envio de imagem antes de continuar.');
      return;
    }
    final generation = _loadGeneration;
    final api = widget.api;
    final occurrence = _occurrence;
    final draft = _draft;
    if (api == null || occurrence == null || draft == null || _saving) return;
    if (!occurrence.canEdit || _state == _ProductionResponseState.unauthorized) return;
    if (_state != _ProductionResponseState.content ||
        (kind == _ResponseCommandKind.save && draft.status != FormResponseDraftStatus.draft) ||
        (kind == _ResponseCommandKind.edit && draft.status != FormResponseDraftStatus.submitted)) {
      return;
    }
    if (_pendingCommand != null && _pendingCommand!.kind != kind) return;
    if (_pendingCommand == null && _invalidAnswerReasons.isNotEmpty) {
      setState(() => _message = 'Revise os valores numéricos antes de salvar.');
      return;
    }
    if (_pendingCommand == null) {
      for (final item in occurrence.version.sections.expand((section) => section.items)) {
        if (_isVisible(item) && _hasAnswer(item)) {
          if (_unanswerableConfiguration(item) case final issue?) {
            setState(() => _message = issue);
            return;
          }
        }
      }
    }
    if (automatic && _autosavePaused) return;
    if (!automatic) _autosavePaused = false;
    final submitted = kind == _ResponseCommandKind.submit || kind == _ResponseCommandKind.edit;
    final answerRevision = _pendingCommand?.answerRevision ?? _answerRevision;
    setState(() {
      _saving = true;
      _message = kind == _ResponseCommandKind.save ? 'Salvando rascunho…' : null;
    });
    try {
      final command =
          _pendingCommand?.command ??
          FormCommand(
            requestId: _newResponseRequestId(),
            expectedVersion: draft.managementVersion,
            payload: FormResponseDraftPayload(
              occurrenceId: occurrence.occurrence.id,
              responseId: draft.id,
              participationId: occurrence.participationId,
              editSecret: _editSecret,
              answers: const FormAnswerNormalizer().normalize(
                answers: _answers,
                visibleItemIds: _visibleItemIds,
              ),
            ),
          );
      _pendingCommand = (kind: kind, command: command, answerRevision: answerRevision);
      final updated = await switch (kind) {
        _ResponseCommandKind.save => api.saveResponseDraft(command),
        _ResponseCommandKind.submit => api.submitResponse(command),
        _ResponseCommandKind.edit => api.editResponse(command),
      };
      if (!_isCurrent(generation)) return;
      setState(() {
        _draft = updated;
        _pendingCommand = null;
        _savedAnswerRevision = answerRevision;
        if (answerRevision == _answerRevision ||
            submitted ||
            updated.status == FormResponseDraftStatus.submitted) {
          _invalidAnswerReasons.clear();
          _answers
            ..clear()
            ..addAll(updated.answers);
          _savedAnswerRevision = _answerRevision;
        }
        _pruneHiddenAnswers();
        _review = false;
        _state = submitted || updated.status == FormResponseDraftStatus.submitted
            ? _ProductionResponseState.submitted
            : _ProductionResponseState.content;
        if (!submitted &&
            updated.status != FormResponseDraftStatus.submitted &&
            answerRevision != _answerRevision) {
          _message = 'Salvamento anterior confirmado. Há alterações locais ainda não salvas.';
        } else if (kind == _ResponseCommandKind.save) {
          _message = 'Rascunho salvo.';
        }
      });
    } on FormApiException catch (error) {
      if (_isCurrent(generation)) {
        setState(() {
          _autosavePaused = true;
          if (error.kind == FormApiFailureKind.unauthorized) {
            _state = _ProductionResponseState.unauthorized;
          }
          if (error.kind == FormApiFailureKind.validation ||
              error.kind == FormApiFailureKind.conflict) {
            _pendingCommand = null;
          }
          _message = error.message;
        });
      }
    } on Object {
      if (_isCurrent(generation)) {
        setState(() {
          _autosavePaused = true;
          _message = 'Não foi possível salvar sua resposta agora.';
        });
      }
    } finally {
      if (_isCurrent(generation)) {
        setState(() => _saving = false);
        _scheduleAutosave();
      }
    }
  }
}

String _civilDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/'
    '${value.year}';

String _answerLabel(FormItem item, FormAnswer answer) => switch (answer.value) {
  FormShortTextValue(:final value) => value,
  FormIntegerValue(:final value) => '$value',
  FormDecimalValue(:final value) => '$value',
  FormMoneyValue(:final minorUnits) => FormNumericLimits.format(FormItemKind.money, minorUnits),
  // Mesmo formato do campo: um valor nao pode ter duas leituras na mesma tela.
  FormDateValue(:final value) => _civilDate(value),
  FormYesNoValue(:final value) => value ? 'Sim' : 'Não',
  // Rotulo escolhido, na ordem autorada. Juntar os IDs mostrava identificador
  // interno a quem respondeu e nao dizia nada sobre a escolha.
  FormChoiceValue(:final optionIds) =>
    (item.options.where((option) => optionIds.contains(option.id)).toList()..sort(
          (a, b) =>
              a.position != b.position ? a.position.compareTo(b.position) : a.id.compareTo(b.id),
        ))
        .map((option) => option.label)
        .join(', '),
  FormScaleValue(:final value) => '$value',
  FormAssetValue(:final assetIds) => '${assetIds.length} arquivo(s)',
};

String _newResponseRequestId() {
  final values = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  final hex = values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

final class _AutosaveStates extends StatelessWidget {
  const _AutosaveStates({required this.available, required this.state});

  final bool available;
  final FormResponseAutosaveState state;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Estados da sincronização local', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: CoeloSpacing.space2),
      Semantics(
        liveRegion: true,
        label: available ? 'Sincronização local: ${_autosaveLabel(state)}' : null,
        child: Chip(label: Text(available ? _autosaveLabel(state) : 'Sincronização indisponível')),
      ),
    ],
  );
}

final class _ResponseUploads extends StatelessWidget {
  const _ResponseUploads({required this.available, required this.canceled, required this.onCancel});

  final bool available;
  final bool canceled;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Anexos protegidos', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: CoeloSpacing.space2),
      if (canceled)
        const CoeloStatePanel(
          icon: Icons.cancel_outlined,
          title: 'Upload cancelado',
          message: 'A resposta local permanece disponível para revisão.',
        )
      else ...[
        LinearProgressIndicator(
          key: Key('form-response-upload-progress'),
          value: available ? .58 : 0,
          semanticsLabel: available ? 'Upload protegido em andamento' : 'Upload indisponível',
          semanticsValue: available ? '58' : '0',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: available ? onCancel : null,
            child: const Text('Cancelar upload'),
          ),
        ),
      ],
      if (available)
        const ListTile(
          leading: Icon(Icons.error_outline_rounded),
          title: Text('Falha no envio de imagem'),
          subtitle: Text('Tente novamente sem perder as demais respostas.'),
        ),
      const ListTile(
        leading: Icon(Icons.lock_outline_rounded),
        title: Text('Mídia protegida indisponível'),
        subtitle: Text('O arquivo será resolvido somente por acesso temporário autorizado.'),
      ),
    ],
  );
}

String _autosaveLabel(FormResponseAutosaveState state) => switch (state) {
  FormResponseAutosaveState.initial => 'Inicial',
  FormResponseAutosaveState.changed => 'Alterado',
  FormResponseAutosaveState.saving => 'Salvando',
  FormResponseAutosaveState.saved => 'Salvo',
  FormResponseAutosaveState.conflict => 'Conflito',
  FormResponseAutosaveState.failure => 'Falha',
};
