import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

final class FormResponsePage extends StatefulWidget {
  const FormResponsePage({super.key})
    : development = false,
      anonymous = false,
      secretLost = false,
      failSubmission = false;

  const FormResponsePage.development({
    this.anonymous = false,
    this.secretLost = false,
    this.failSubmission = false,
    super.key,
  }) : development = true;

  final bool development;
  final bool anonymous;
  final bool secretLost;
  final bool failSubmission;

  @override
  State<FormResponsePage> createState() => _FormResponsePageState();
}

final class _FormResponsePageState extends State<FormResponsePage> {
  final _answer = TextEditingController();
  bool _review = false;
  bool _submitted = false;
  bool _failed = false;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
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
                widget.development ? 'Pesquisa das famílias' : 'Formulário sem dados disponíveis',
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
      _AutosaveStates(available: widget.development),
      const SizedBox(height: CoeloSpacing.space5),
      _ResponseUploads(available: widget.development),
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
  const _AutosaveStates({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Estados da sincronização local', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: CoeloSpacing.space2),
      Wrap(
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: available
            ? const [
                Chip(label: Text('Alterado')),
                Chip(label: Text('Salvando')),
                Chip(label: Text('Salvo')),
                Chip(label: Text('Conflito')),
                Chip(label: Text('Falha')),
              ]
            : const [Chip(label: Text('Sincronização indisponível'))],
      ),
    ],
  );
}

final class _ResponseUploads extends StatelessWidget {
  const _ResponseUploads({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Anexos protegidos', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: CoeloSpacing.space2),
      LinearProgressIndicator(
        key: Key('form-response-upload-progress'),
        value: available ? .58 : 0,
        semanticsLabel: available ? 'Upload protegido em andamento' : 'Upload indisponível',
        semanticsValue: available ? '58' : '0',
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: available ? () {} : null,
          child: const Text('Cancelar upload'),
        ),
      ),
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
