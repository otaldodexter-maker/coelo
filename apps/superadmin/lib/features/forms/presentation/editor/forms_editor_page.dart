import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';

/// Production remains fail-closed. The named development constructor is used
/// only by the `/dev` composition root and never claims remote persistence.
final class FormsEditorPage extends StatefulWidget {
  const FormsEditorPage({super.key}) : development = false;

  const FormsEditorPage.development({super.key}) : development = true;

  final bool development;

  @override
  State<FormsEditorPage> createState() => _FormsEditorPageState();
}

final class _FormsEditorPageState extends State<FormsEditorPage> {
  static const _labels = ['Identificação', 'Perguntas', 'Revisão'];

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _question = TextEditingController();
  var _step = 0;
  String? _error;
  var _saved = false;

  bool get _dirty =>
      _title.text.isNotEmpty || _description.text.isNotEmpty || _question.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    for (final controller in [_title, _description, _question]) {
      controller.addListener(_draftChanged);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.development) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: CoeloStatePanel(
              title: 'Editor de formulários indisponível',
              message: 'A edição de formulários está temporariamente indisponível.',
              icon: Icons.lock_outline_rounded,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => SuperadminFormFrame(
        viewportWidth: constraints.maxWidth,
        scrollKey: const Key('forms-dev-scroll'),
        navigation: SuperadminFormStepNavigation(
          steps: [
            for (var index = 0; index < _labels.length; index++)
              SuperadminFormStep(
                label: _labels[index],
                status: index == _step
                    ? (_error == null
                          ? SuperadminFormStepStatus.current
                          : SuperadminFormStepStatus.error)
                    : index < _step
                    ? SuperadminFormStepStatus.complete
                    : SuperadminFormStepStatus.incomplete,
                enabled: index <= _step,
              ),
          ],
          currentIndex: _step,
          onStepSelected: (index) => setState(() {
            _step = index;
            _error = null;
            _saved = false;
          }),
        ),
        body: _body(),
        footer: SuperadminFormActionFooter(
          tertiaryAction: TextButton(
            onPressed: _dirty ? _confirmClearDraft : null,
            child: const Text('Limpar rascunho'),
          ),
          continuationActions: [
            if (_step > 0) OutlinedButton(onPressed: _back, child: const Text('Anterior')),
            FilledButton(
              onPressed: _step == _labels.length - 1 ? _saveLocal : _continue,
              child: Text(_step == _labels.length - 1 ? 'Salvar rascunho local' : 'Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const CoeloStatePanel(
        title: 'Prévia de desenvolvimento',
        message: 'Os dados ficam somente nesta tela e não são enviados ao ambiente produtivo.',
        icon: Icons.science_outlined,
      ),
      const SizedBox(height: CoeloSpacing.space5),
      Text(_labels[_step], style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: CoeloSpacing.space1),
      Text('Etapa ${_step + 1} de ${_labels.length}'),
      const SizedBox(height: CoeloSpacing.space4),
      if (_error != null) ...[
        CoeloStatePanel(title: 'Revise esta etapa', message: _error!, icon: Icons.info_outline),
        const SizedBox(height: CoeloSpacing.space4),
      ],
      switch (_step) {
        0 => _identification(),
        1 => _questions(),
        _ => _review(),
      },
      if (_saved) ...[
        const SizedBox(height: CoeloSpacing.space4),
        const CoeloStatePanel(
          title: 'Rascunho local',
          message: 'Rascunho salvo somente nesta prévia.',
          icon: Icons.check_circle_outline_rounded,
        ),
      ],
    ],
  );

  Widget _identification() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CoeloFormTextField(
        key: const Key('forms-dev-title'),
        controller: _title,
        labelText: 'Título do formulário',
        prefixIcon: Icons.description_outlined,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        controller: _description,
        labelText: 'Descrição',
        prefixIcon: Icons.notes_outlined,
        maxLines: 4,
      ),
    ],
  );

  Widget _questions() => CoeloFormTextField(
    key: const Key('forms-dev-question'),
    controller: _question,
    labelText: 'Primeira pergunta',
    prefixIcon: Icons.help_outline_rounded,
    maxLines: 4,
  );

  Widget _review() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _reviewRow('Título', _title.text),
      _reviewRow('Descrição', _description.text),
      _reviewRow('Pergunta', _question.text),
    ],
  );

  Widget _reviewRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: CoeloSpacing.space1),
        Text(value.trim().isEmpty ? 'Não informado' : value.trim()),
      ],
    ),
  );

  void _continue() {
    final error = switch (_step) {
      0 when _title.text.trim().isEmpty => 'Informe o título do formulário.',
      1 when _question.text.trim().isEmpty => 'Informe ao menos uma pergunta.',
      _ => null,
    };
    setState(() {
      _error = error;
      _saved = false;
      if (error == null) _step++;
    });
  }

  void _back() => setState(() {
    _step--;
    _error = null;
    _saved = false;
  });

  void _saveLocal() => setState(() {
    _error = null;
    _saved = true;
  });

  void _draftChanged() {
    if (mounted) setState(() => _saved = false);
  }

  Future<void> _confirmClearDraft() async {
    if (!_dirty) return;
    final clear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CoeloAdminDialogShell(
        title: 'Limpar rascunho?',
        body: const Text('Os dados preenchidos nesta prévia serão descartados.'),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Continuar editando'),
        ),
        primaryAction: FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          child: const Text('Limpar'),
        ),
      ),
    );
    if (clear == true && mounted) _clearDraft();
  }

  void _clearDraft() {
    _title.clear();
    _description.clear();
    _question.clear();
    setState(() {
      _step = 0;
      _error = null;
      _saved = false;
    });
  }
}
