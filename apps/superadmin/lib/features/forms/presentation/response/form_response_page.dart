import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../data/development_forms_api.dart';

enum FormResponseAutosaveState { initial, changed, saving, saved, conflict, failure }

final class FormResponsePage extends StatefulWidget {
  const FormResponsePage({super.key})
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
  }) : development = true;

  final bool development;
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
              if (!widget.development) ...[
                const CoeloStatePanel(
                  key: Key('form-response-unavailable'),
                  icon: Icons.lock_outline_rounded,
                  title: 'Resposta indisponível',
                  message:
                      'A composição permanece visível, mas conteúdo, retomada, upload e envio dependem de uma fonte autorizada.',
                ),
                const SizedBox(height: CoeloSpacing.space4),
                _buildForm(context),
              ] else if (widget.anonymous && widget.secretLost)
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
