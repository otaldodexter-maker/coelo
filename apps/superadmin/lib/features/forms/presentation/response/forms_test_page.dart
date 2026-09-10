import 'dart:async';
import 'dart:math' as math;

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../data/development_forms_api.dart';
import 'form_response_page.dart';

/// Fail-closed in production. The development constructor provides a local,
/// deterministic respondent preview without repositories or remote writes.
///
/// In production the surface has two authorized shapes. With an
/// [occurrenceId] it delegates to the real response flow. With a [formId] and
/// no occurrence it previews the authored definition read-only: it reads the
/// same authorized projection the editor reads and never opens, saves or
/// submits a response, which is what testing a form before publishing means.
final class FormsTestPage extends StatefulWidget {
  const FormsTestPage({this.api, this.occurrenceId, this.formId, super.key})
    : development = false,
      anonymous = false;

  const FormsTestPage.development({this.anonymous = false, this.formId, super.key})
    : development = true,
      api = null,
      occurrenceId = null;

  /// True when this instance must preview an authored definition instead of
  /// delegating to a real response.
  bool get previewsDefinition =>
      !development && occurrenceId == null && formId != null && api != null;

  final bool development;
  final FormsApi? api;
  final String? occurrenceId;
  final bool anonymous;
  final String? formId;

  @override
  State<FormsTestPage> createState() => _FormsTestPageState();
}

enum _FormsTestPreview { responsive, tablet, mobile }

final class _FormsTestPageState extends State<FormsTestPage> {
  final _comment = TextEditingController();
  late bool _anonymous = widget.anonymous;
  _FormsTestPreview _preview = _FormsTestPreview.responsive;
  FormDefinition? _definition;
  bool _definitionRefused = false;
  int _loadGeneration = 0;
  String? _rating;
  int _step = 0;
  bool _showValidation = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    if (widget.previewsDefinition) unawaited(_loadDefinition());
  }

  @override
  void didUpdateWidget(covariant FormsTestPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.previewsDefinition &&
        (oldWidget.formId != widget.formId || !identical(oldWidget.api, widget.api))) {
      unawaited(_loadDefinition());
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _comment.dispose();
    super.dispose();
  }

  /// Reads the same authorized projection the editor reads. A return that
  /// arrives after dispose or after a context change is dropped.
  Future<void> _loadDefinition() async {
    final generation = ++_loadGeneration;
    // Drop the previous form before loading the next one. Keeping it on screen
    // would show one form's questions under another form's id while it loads.
    if (_definition != null || _definitionRefused) {
      setState(() {
        _definition = null;
        _definitionRefused = false;
      });
    }
    try {
      final projection = await widget.api!.getEditor(widget.formId!);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _definition = projection.definition;
        _definitionRefused = false;
      });
    } on Object {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _definition = null;
        _definitionRefused = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.previewsDefinition) return _definitionScaffold(context);
    if (!widget.development) {
      return FormResponsePage(api: widget.api, occurrenceId: widget.occurrenceId);
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
                _AvailabilityNotice(development: widget.development),
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

  /// The authored form, rendered read-only inside the same preview frame.
  /// Nothing here can answer, save or submit.
  Widget _definitionScaffold(BuildContext context) => Scaffold(
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
              if (_definitionRefused)
                const _AvailabilityNotice(development: false)
              else ...[
                DecoratedBox(
                  key: const Key('forms-test-no-persistence'),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(CoeloRadius.md),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(CoeloSpacing.space3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.visibility_outlined),
                        const SizedBox(width: CoeloSpacing.space2),
                        Expanded(
                          child: Text(
                            'Pré-visualização do formulário autorado · '
                            'nenhuma resposta é aberta, salva ou enviada',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: CoeloSpacing.space4),
                _previewControls(),
                const SizedBox(height: CoeloSpacing.space4),
                _previewFrame(child: _definitionPreview(context)),
              ],
            ],
          );
        },
      ),
    ),
  );

  Widget _previewFrame({required Widget child}) => LayoutBuilder(
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
            child: child,
          ),
        ),
      );
    },
  );

  Widget _definitionPreview(BuildContext context) {
    if (_definition case final definition?) {
      return Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(definition.title, style: Theme.of(context).textTheme.headlineSmall),
            if (definition.description case final description?
                when description.trim().isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space1),
              Text(description),
            ],
            const SizedBox(height: CoeloSpacing.space1),
            Text(
              definition.identityMode == FormIdentityMode.anonymous
                  ? 'Resposta anônima'
                  : 'Resposta identificada',
            ),
            for (final section in definition.sections) ...[
              const SizedBox(height: CoeloSpacing.space5),
              Text(section.title, style: Theme.of(context).textTheme.titleLarge),
              if (section.description case final description?
                  when description.trim().isNotEmpty) ...[
                const SizedBox(height: CoeloSpacing.space1),
                Text(description),
              ],
              for (final item in section.items) ...[
                const SizedBox(height: CoeloSpacing.space4),
                _PreviewItem(item: item),
              ],
            ],
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(CoeloSpacing.space6),
      child: Center(
        child: CircularProgressIndicator(
          key: Key('forms-test-preview-loading'),
          semanticsLabel: 'Carregando a pré-visualização do formulário',
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
        onSelected: widget.development
            ? (_) => setState(() => _preview = _FormsTestPreview.responsive)
            : null,
      ),
      ChoiceChip(
        key: const Key('forms-test-preview-tablet'),
        label: const Text('Tablet'),
        selected: _preview == _FormsTestPreview.tablet,
        onSelected: widget.development
            ? (_) => setState(() => _preview = _FormsTestPreview.tablet)
            : null,
      ),
      ChoiceChip(
        key: const Key('forms-test-preview-mobile'),
        label: const Text('Celular'),
        selected: _preview == _FormsTestPreview.mobile,
        onSelected: widget.development
            ? (_) => setState(() => _preview = _FormsTestPreview.mobile)
            : null,
      ),
      const SizedBox(width: CoeloSpacing.space2),
      ChoiceChip(
        label: const Text('Identificada'),
        selected: !_anonymous,
        onSelected: widget.development ? (_) => setState(() => _anonymous = false) : null,
      ),
      ChoiceChip(
        label: const Text('Anônima'),
        selected: _anonymous,
        onSelected: widget.development ? (_) => setState(() => _anonymous = true) : null,
      ),
    ],
  );

  Widget _responsePreview() => Padding(
    padding: const EdgeInsets.all(CoeloSpacing.space4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.development
              ? developmentFormTitle(widget.formId, fallback: 'Pesquisa das famílias')
              : 'Formulário sem dados disponíveis',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: CoeloSpacing.space1),
        Text(
          widget.development
              ? (_anonymous ? 'Resposta anônima' : 'Resposta identificada')
              : 'Identidade indisponível',
        ),
        const SizedBox(height: CoeloSpacing.space2),
        if (!widget.development)
          const Text('Conteúdo e identidade serão carregados somente por uma fonte autorizada.')
        else if (_anonymous)
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
          for (final option
              in widget.development
                  ? const ['Muito boa', 'Boa', 'Pode melhorar']
                  : const ['Opção 1', 'Opção 2', 'Opção 3'])
            ChoiceChip(
              label: Text(option),
              selected: _rating == option,
              onSelected: widget.development
                  ? (_) => setState(() {
                      _rating = option;
                      _showValidation = false;
                    })
                  : null,
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
        enabled: widget.development,
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
          onPressed: widget.development ? _next : null,
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
            onPressed: widget.development ? () => setState(() => _step = 0) : null,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Voltar e editar'),
          ),
          FilledButton.icon(
            key: const Key('forms-test-finish'),
            onPressed: widget.development ? () => setState(() => _finished = true) : null,
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

final class _AvailabilityNotice extends StatelessWidget {
  const _AvailabilityNotice({required this.development});

  final bool development;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: development ? null : const Key('forms-test-unavailable'),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(CoeloRadius.md),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(development ? Icons.science_outlined : Icons.lock_outline_rounded),
          const SizedBox(width: CoeloSpacing.space2),
          Expanded(
            child: Text(
              development
                  ? 'Fixture local · nenhuma resposta será persistida'
                  : 'Teste indisponível · conteúdo neutro e ações bloqueadas até existir uma fonte autorizada',
            ),
          ),
        ],
      ),
    ),
  );
}

/// One authored question, shown as the respondent will see it but with every
/// control inert: this surface must never be able to produce an answer.
final class _PreviewItem extends StatelessWidget {
  const _PreviewItem({required this.item});

  final FormItem item;

  @override
  Widget build(BuildContext context) {
    if (item.kind == FormItemKind.information) {
      return CoeloStatePanel(
        icon: Icons.info_outline_rounded,
        title: item.label,
        message: item.helpText ?? '',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${item.label}${item.isRequired ? ' *' : ''}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (item.helpText case final help? when help.trim().isNotEmpty) ...[
          const SizedBox(height: CoeloSpacing.space1),
          Text(help, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (_limits(item) case final limits? when limits.isNotEmpty) ...[
          const SizedBox(height: CoeloSpacing.space1),
          Text(limits, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: CoeloSpacing.space2),
        _control(context),
      ],
    );
  }

  /// The authored limits, in the same civil notation the respondent sees, so
  /// the author can check them before publishing.
  String? _limits(FormItem item) {
    final parts = <String>[];
    if (FormNumericLimits.isNumeric(item.kind)) {
      if (item.config.minValue case final minimum?) {
        parts.add('mínimo ${FormNumericLimits.format(item.kind, minimum)}');
      }
      if (item.config.maxValue case final maximum?) {
        parts.add('máximo ${FormNumericLimits.format(item.kind, maximum)}');
      }
    }
    if (item.config.maxLength case final maximum?) parts.add('até $maximum caracteres');
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _control(BuildContext context) => switch (item.kind) {
    FormItemKind.singleChoice || FormItemKind.multipleChoice => Wrap(
      spacing: CoeloSpacing.space2,
      runSpacing: CoeloSpacing.space2,
      children: [
        for (final option in item.options)
          ChoiceChip(label: Text(option.label), selected: false, onSelected: null),
      ],
    ),
    FormItemKind.yesNo => const Wrap(
      spacing: CoeloSpacing.space2,
      children: [
        ChoiceChip(label: Text('Sim'), selected: false, onSelected: null),
        ChoiceChip(label: Text('Não'), selected: false, onSelected: null),
      ],
    ),
    _ => TextFormField(
      key: Key('forms-test-preview-item-${item.id}'),
      enabled: false,
      minLines: item.kind == FormItemKind.shortText ? 2 : 1,
      maxLines: item.kind == FormItemKind.shortText ? 6 : 1,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: switch (item.kind) {
          FormItemKind.integer => 'Número inteiro',
          FormItemKind.decimal => 'Número',
          FormItemKind.money => 'Valor',
          FormItemKind.date => 'Data',
          FormItemKind.scale => 'Escala',
          FormItemKind.photo => 'Foto',
          FormItemKind.gallery => 'Imagens',
          _ => 'Resposta',
        },
      ),
    ),
  };
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
