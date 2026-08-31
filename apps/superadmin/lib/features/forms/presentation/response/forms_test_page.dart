import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

/// Fail-closed in production. The development constructor provides a local,
/// deterministic respondent preview without repositories or remote writes.
final class FormsTestPage extends StatefulWidget {
  const FormsTestPage({super.key}) : development = false, anonymous = false;

  const FormsTestPage.development({this.anonymous = false, super.key}) : development = true;

  final bool development;
  final bool anonymous;

  @override
  State<FormsTestPage> createState() => _FormsTestPageState();
}

enum _FormsTestPreview { responsive, tablet, mobile }

final class _FormsTestPageState extends State<FormsTestPage> {
  final _comment = TextEditingController();
  late bool _anonymous = widget.anonymous;
  _FormsTestPreview _preview = _FormsTestPreview.responsive;
  String? _rating;
  int _step = 0;
  bool _showValidation = false;
  bool _finished = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.development) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: CoeloStatePanel(
              title: 'Teste de formulário indisponível',
              message: 'O teste de formulários está temporariamente indisponível.',
              icon: Icons.lock_outline_rounded,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
            final inset = compact ? CoeloSpacing.space4 : CoeloSpacing.space6;
            return ListView(
              key: const Key('forms-test-scroll'),
              padding: EdgeInsets.fromLTRB(inset, CoeloSpacing.space5, inset, CoeloSpacing.space8),
              children: [
                Text('Teste do formulário', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: CoeloSpacing.space1),
                Text(
                  'Confira o fluxo como uma pessoa respondente antes de publicar.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: CoeloSpacing.space3),
                const _LocalFixtureNotice(),
                const SizedBox(height: CoeloSpacing.space4),
                _previewControls(),
                const SizedBox(height: CoeloSpacing.space4),
                LayoutBuilder(
                  builder: (context, previewConstraints) {
                    final targetWidth = switch (_preview) {
                      _FormsTestPreview.responsive => 860.0,
                      _FormsTestPreview.tablet => 768.0,
                      _FormsTestPreview.mobile => 375.0,
                    };
                    return Align(
                      alignment: Alignment.topCenter,
                      child: AnimatedContainer(
                        key: const Key('forms-test-preview'),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                        width: math.min(targetWidth, previewConstraints.maxWidth),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(CoeloRadius.lg),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(CoeloRadius.lg),
                          child: _responsePreview(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _previewControls() => Wrap(
    spacing: CoeloSpacing.space3,
    runSpacing: CoeloSpacing.space3,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text('Preview', style: Theme.of(context).textTheme.titleSmall),
      ChoiceChip(
        key: const Key('forms-test-preview-responsive'),
        label: const Text('Responsivo'),
        selected: _preview == _FormsTestPreview.responsive,
        onSelected: (_) => setState(() => _preview = _FormsTestPreview.responsive),
      ),
      ChoiceChip(
        key: const Key('forms-test-preview-tablet'),
        label: const Text('Tablet'),
        selected: _preview == _FormsTestPreview.tablet,
        onSelected: (_) => setState(() => _preview = _FormsTestPreview.tablet),
      ),
      ChoiceChip(
        key: const Key('forms-test-preview-mobile'),
        label: const Text('Celular'),
        selected: _preview == _FormsTestPreview.mobile,
        onSelected: (_) => setState(() => _preview = _FormsTestPreview.mobile),
      ),
      const SizedBox(width: CoeloSpacing.space2),
      ChoiceChip(
        label: const Text('Identificada'),
        selected: !_anonymous,
        onSelected: (_) => setState(() => _anonymous = false),
      ),
      ChoiceChip(
        label: const Text('Anônima'),
        selected: _anonymous,
        onSelected: (_) => setState(() => _anonymous = true),
      ),
    ],
  );

  Widget _responsePreview() => Padding(
    padding: const EdgeInsets.all(CoeloSpacing.space4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pesquisa das famílias', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: CoeloSpacing.space1),
        Text(_anonymous ? 'Resposta anônima' : 'Resposta identificada'),
        const SizedBox(height: CoeloSpacing.space2),
        if (_anonymous)
          const Text(
            'Este modo não registra identidade. Guarde o segredo de retomada quando disponível.',
          )
        else
          const Text('Respondendo como Helena Martins · Responsável'),
        const SizedBox(height: CoeloSpacing.space4),
        LinearProgressIndicator(
          value: _step == 0 ? .5 : 1,
          semanticsLabel: 'Progresso do teste de formulário',
          semanticsValue: _step == 0 ? '50%' : '100%',
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Text('Etapa ${_step + 1} de 2'),
        const SizedBox(height: CoeloSpacing.space5),
        if (_finished)
          CoeloStatePanel(
            icon: Icons.task_alt_rounded,
            title: 'Teste concluído nesta demonstração',
            message: 'Nenhuma persistência remota foi realizada.',
            actionLabel: 'Recomeçar teste',
            onAction: _restart,
          )
        else if (_step == 0)
          _questions()
        else
          _review(),
      ],
    ),
  );

  Widget _questions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Como você avalia a comunicação da instituição? *',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: CoeloSpacing.space2),
      Wrap(
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: [
          for (final option in const ['Muito boa', 'Boa', 'Pode melhorar'])
            ChoiceChip(
              label: Text(option),
              selected: _rating == option,
              onSelected: (_) => setState(() {
                _rating = option;
                _showValidation = false;
              }),
            ),
        ],
      ),
      if (_showValidation) ...[
        const SizedBox(height: CoeloSpacing.space2),
        Text(
          'Selecione uma opção para continuar.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: CoeloSpacing.space5),
      TextFormField(
        key: const Key('forms-test-comment'),
        controller: _comment,
        minLines: 3,
        maxLines: 6,
        decoration: const InputDecoration(
          labelText: 'Conte mais (opcional)',
          hintText: 'Escreva sua contribuição',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: CoeloSpacing.space4),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          key: const Key('forms-test-next'),
          onPressed: _next,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Revisar resposta'),
        ),
      ),
    ],
  );

  Widget _review() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Revise sua resposta', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: CoeloSpacing.space4),
      _ReviewField(label: 'Avaliação', value: _rating!),
      const SizedBox(height: CoeloSpacing.space3),
      _ReviewField(
        label: 'Comentário',
        value: _comment.text.trim().isEmpty ? 'Não informado' : _comment.text.trim(),
      ),
      const SizedBox(height: CoeloSpacing.space5),
      Wrap(
        alignment: WrapAlignment.end,
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: [
          OutlinedButton.icon(
            key: const Key('forms-test-back'),
            onPressed: () => setState(() => _step = 0),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Voltar e editar'),
          ),
          FilledButton.icon(
            key: const Key('forms-test-finish'),
            onPressed: () => setState(() => _finished = true),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Concluir teste local'),
          ),
        ],
      ),
    ],
  );

  void _next() {
    if (_rating == null) {
      setState(() => _showValidation = true);
      return;
    }
    setState(() {
      _showValidation = false;
      _step = 1;
    });
  }

  void _restart() => setState(() {
    _rating = null;
    _comment.clear();
    _step = 0;
    _showValidation = false;
    _finished = false;
  });
}

final class _LocalFixtureNotice extends StatelessWidget {
  const _LocalFixtureNotice();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(CoeloRadius.md),
    ),
    child: const Padding(
      padding: EdgeInsets.all(CoeloSpacing.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined),
          SizedBox(width: CoeloSpacing.space2),
          Expanded(child: Text('Fixture local · nenhuma resposta será persistida')),
        ],
      ),
    ),
  );
}

final class _ReviewField extends StatelessWidget {
  const _ReviewField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.md),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: CoeloSpacing.space1),
          Text(value),
        ],
      ),
    ),
  );
}
