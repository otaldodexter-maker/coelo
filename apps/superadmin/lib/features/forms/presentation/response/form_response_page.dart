import 'dart:async';
import 'dart:math';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../data/development_forms_api.dart';

enum FormResponseAutosaveState { initial, changed, saving, saved, conflict, failure }

final class FormResponsePage extends StatefulWidget {
  const FormResponsePage({this.api, this.occurrenceId, super.key})
    : development = false,
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
       occurrenceId = null;

  final bool development;
  final FormsApi? api;
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
      return _ProductionFormResponse(api: widget.api, occurrenceId: widget.occurrenceId);
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
  const _ProductionFormResponse({required this.api, required this.occurrenceId});

  final FormsApi? api;
  final String? occurrenceId;

  @override
  State<_ProductionFormResponse> createState() => _ProductionFormResponseState();
}

final class _ProductionFormResponseState extends State<_ProductionFormResponse> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, FormAnswer> _answers = {};
  _ProductionResponseState _state = _ProductionResponseState.loading;
  FormOccurrenceForResponse? _occurrence;
  FormResponseDraft? _draft;
  String? _message;
  bool _review = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = widget.api;
    final occurrenceId = widget.occurrenceId;
    if (api == null || occurrenceId == null || occurrenceId.isEmpty) {
      setState(() => _state = _ProductionResponseState.unavailable);
      return;
    }
    try {
      final occurrence = await api.getOccurrenceForResponse(occurrenceId);
      if (occurrence.draft == null && !occurrence.canEdit) {
        if (mounted) {
          setState(() {
            _message = 'A fonte autorizada não permite iniciar ou editar esta resposta.';
            _state = _ProductionResponseState.unauthorized;
          });
        }
        return;
      }
      final draft =
          occurrence.draft ??
          await api.openResponseDraft(
            FormCommand(
              requestId: _newResponseRequestId(),
              expectedVersion: 0,
              payload: FormOpenResponseDraftPayload(
                occurrenceId: occurrence.occurrence.id,
                participationId: occurrence.participationId,
                identityMode: occurrence.identityMode,
              ),
            ),
          );
      if (!mounted) return;
      setState(() {
        _occurrence = occurrence;
        _draft = draft;
        _answers
          ..clear()
          ..addAll(draft.answers);
        _state = draft.status == FormResponseDraftStatus.submitted
            ? _ProductionResponseState.submitted
            : occurrence.canEdit
            ? _ProductionResponseState.content
            : _ProductionResponseState.unauthorized;
        if (_state == _ProductionResponseState.unauthorized) {
          _message = 'A fonte autorizada não permite editar esta resposta.';
        }
      });
    } on FormApiException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _state = error.kind == FormApiFailureKind.unauthorized
              ? _ProductionResponseState.unauthorized
              : _ProductionResponseState.error;
        });
      }
    } on Object {
      if (mounted) {
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
                onAction: _load,
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
        onAction: _occurrence!.canEdit ? _editSubmittedResponse : null,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      _answerSummary(context),
    ],
  );

  Widget _responseForm(BuildContext context) {
    final occurrence = _occurrence!;
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
          const SizedBox(height: CoeloSpacing.space5),
          for (final section in occurrence.version.sections) ...[
            Text(section.title, style: Theme.of(context).textTheme.titleLarge),
            if (section.description case final description?) ...[
              const SizedBox(height: CoeloSpacing.space1),
              Text(description),
            ],
            const SizedBox(height: CoeloSpacing.space3),
            for (final item in section.items)
              if (_isVisible(item)) ...[
                _itemField(context, item),
                const SizedBox(height: CoeloSpacing.space4),
              ],
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
              OutlinedButton(
                key: const Key('form-response-save-draft'),
                onPressed: _saving ? null : _saveDraft,
                child: const Text('Salvar rascunho'),
              ),
              FilledButton.icon(
                key: const Key('form-response-review'),
                onPressed: _saving ? null : _reviewResponse,
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
                  onPressed: _saving ? null : () => setState(() => _review = false),
                  child: const Text('Voltar e editar'),
                ),
                FilledButton(
                  key: const Key('form-response-submit'),
                  onPressed: _saving ? null : _submit,
                  child: Text(_saving ? 'Enviando…' : 'Enviar resposta'),
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
              if (item.kind != FormItemKind.information)
                if (_answers[item.id] case final FormAnswer answer)
                  Padding(
                    padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
                    child: Text('${item.label}: ${_answerLabel(answer)}'),
                  ),
        ],
      ),
    ),
  );

  Widget _itemField(BuildContext context, FormItem item) {
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
    final help = item.helpText;
    final field = switch (item.kind) {
      FormItemKind.shortText => TextFormField(
        key: Key('form-response-item-${item.id}'),
        initialValue: _textValue(item.id),
        minLines: 2,
        maxLines: 6,
        onChanged: (value) => _setAnswer(
          item,
          value.trim().isEmpty ? null : FormAnswer.shortText(itemId: item.id, value: value),
        ),
        validator: (_) => _requiredMessage(item),
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      FormItemKind.integer || FormItemKind.decimal || FormItemKind.money => TextFormField(
        key: Key('form-response-item-${item.id}'),
        initialValue: _numberValue(item.id),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (value) => _setNumericAnswer(item, value),
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
              onSelected: (_) => setState(
                () => _setAnswer(item, FormAnswer.yesNo(itemId: item.id, value: option)),
              ),
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
              onSelected: (_) => setState(
                () =>
                    _setAnswer(item, FormAnswer.singleChoice(itemId: item.id, optionId: option.id)),
              ),
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
              onSelected: (selected) => setState(() {
                final selectedIds = {...?(_answers[item.id]?.value as FormChoiceValue?)?.optionIds};
                selected ? selectedIds.add(option.id) : selectedIds.remove(option.id);
                _setAnswer(
                  item,
                  selectedIds.isEmpty
                      ? null
                      : FormAnswer.multipleChoice(itemId: item.id, optionIds: selectedIds),
                );
              }),
            ),
        ],
      ),
      FormItemKind.scale => Wrap(
        spacing: CoeloSpacing.space2,
        children: [
          for (
            var value = item.config.scaleMin ?? 0;
            value <= (item.config.scaleMax ?? 10);
            value++
          )
            ChoiceChip(
              label: Text('$value'),
              selected: (_answers[item.id]?.value as FormScaleValue?)?.value == value,
              onSelected: (_) =>
                  setState(() => _setAnswer(item, FormAnswer.scale(itemId: item.id, value: value))),
            ),
        ],
      ),
      FormItemKind.date => OutlinedButton.icon(
        onPressed: () => _pickDate(item),
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text(_dateValue(item.id) ?? 'Selecionar data'),
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

  bool _isVisible(FormItem item) => item.conditions.every((condition) {
    final answer = _answers[condition.sourceItemId]?.value;
    return switch ((condition.kind, answer)) {
      (FormConditionKind.yesNo, FormYesNoValue(:final value)) => value == condition.expectedYesNo,
      (FormConditionKind.choice, FormChoiceValue(:final optionIds)) =>
        optionIds.intersection(condition.optionIds).isNotEmpty,
      _ => false,
    };
  });

  String? _requiredMessage(FormItem item) =>
      item.isRequired && _answers[item.id] == null ? 'Esta resposta é obrigatória.' : null;

  void _setAnswer(FormItem item, FormAnswer? answer) {
    if (answer == null) {
      _answers.remove(item.id);
    } else {
      _answers[item.id] = answer;
    }
  }

  void _setNumericAnswer(FormItem item, String raw) {
    final value = raw.trim();
    if (value.isEmpty) return _setAnswer(item, null);
    final normalized = value.replaceAll(',', '.');
    final answer = switch (item.kind) {
      FormItemKind.integer => switch (int.tryParse(normalized)) {
        final number? => FormAnswer.integer(itemId: item.id, value: number),
        null => null,
      },
      FormItemKind.decimal => switch (double.tryParse(normalized)) {
        final number? => FormAnswer.decimal(itemId: item.id, value: number),
        null => null,
      },
      FormItemKind.money => switch (double.tryParse(normalized)) {
        final number? => FormAnswer.money(itemId: item.id, minorUnits: (number * 100).round()),
        null => null,
      },
      _ => null,
    };
    _setAnswer(item, answer);
  }

  String _textValue(String itemId) => (_answers[itemId]?.value as FormShortTextValue?)?.value ?? '';
  String _numberValue(String itemId) => switch (_answers[itemId]?.value) {
    FormIntegerValue(:final value) => '$value',
    FormDecimalValue(:final value) => '$value',
    FormMoneyValue(:final minorUnits) => '${minorUnits / 100}',
    _ => '',
  };
  String? _dateValue(String itemId) => switch (_answers[itemId]?.value) {
    FormDateValue(:final value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}',
    _ => null,
  };

  Future<void> _pickDate(FormItem item) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: (_answers[item.id]?.value as FormDateValue?)?.value ?? now,
      firstDate: DateTime(now.year - 120),
      lastDate: DateTime(now.year + 20),
    );
    if (selected != null && mounted) {
      setState(() => _setAnswer(item, FormAnswer.date(itemId: item.id, value: selected)));
    }
  }

  void _reviewResponse() {
    if (!_validate()) return;
    setState(() => _review = true);
  }

  bool _validate() {
    final unsupportedRequired = _occurrence!.version.sections
        .expand((section) => section.items)
        .any(
          (item) =>
              item.isRequired &&
              (item.kind == FormItemKind.photo || item.kind == FormItemKind.gallery),
        );
    if (unsupportedRequired) {
      setState(
        () => _message =
            'Este formulário exige anexo e o envio protegido ainda não está disponível nesta superfície.',
      );
      return false;
    }
    return _formKey.currentState?.validate() ?? false;
  }

  Future<void> _saveDraft() => _sendDraft((api, command) => api.saveResponseDraft(command));

  Future<void> _submit() {
    if (!_validate()) return Future.value();
    return _sendDraft((api, command) => api.submitResponse(command), submitted: true);
  }

  Future<void> _editSubmittedResponse() =>
      _sendDraft((api, command) => api.editResponse(command), submitted: false);

  Future<void> _sendDraft(
    Future<FormResponseDraft> Function(FormsApi, FormCommand<FormResponseDraftPayload>) action, {
    bool submitted = false,
  }) async {
    final api = widget.api;
    final occurrence = _occurrence;
    final draft = _draft;
    if (api == null || occurrence == null || draft == null) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final updated = await action(
        api,
        FormCommand(
          requestId: _newResponseRequestId(),
          expectedVersion: draft.managementVersion,
          payload: FormResponseDraftPayload(
            occurrenceId: occurrence.occurrence.id,
            responseId: draft.id,
            participationId: occurrence.participationId,
            answers: _answers,
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        _draft = updated;
        _answers
          ..clear()
          ..addAll(updated.answers);
        _review = false;
        _state = submitted || updated.status == FormResponseDraftStatus.submitted
            ? _ProductionResponseState.submitted
            : _ProductionResponseState.content;
      });
    } on FormApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on Object {
      if (mounted) setState(() => _message = 'Não foi possível salvar sua resposta agora.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _answerLabel(FormAnswer answer) => switch (answer.value) {
  FormShortTextValue(:final value) => value,
  FormIntegerValue(:final value) => '$value',
  FormDecimalValue(:final value) => '$value',
  FormMoneyValue(:final minorUnits) => '${minorUnits / 100}',
  FormDateValue(:final value) => '${value.day}/${value.month}/${value.year}',
  FormYesNoValue(:final value) => value ? 'Sim' : 'Não',
  FormChoiceValue(:final optionIds) => optionIds.join(', '),
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
