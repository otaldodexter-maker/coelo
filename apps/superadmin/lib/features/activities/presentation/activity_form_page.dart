import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../auth/domain/logout_action.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/activity_directory.dart';
import 'activity_form_controller.dart';

enum _ActivityFormLoadState { loading, ready, notFound, failure, unauthorized }

final class ActivityFormPage extends StatefulWidget {
  const ActivityFormPage({
    required this.repository,
    required this.logout,
    required this.onCancel,
    required this.onPrototypeSubmitted,
    this.activityId,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    super.key,
  });

  final String? activityId;
  final ActivityDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback onCancel;
  final VoidCallback onPrototypeSubmitted;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;

  @override
  State<ActivityFormPage> createState() => _ActivityFormPageState();
}

final class _ActivityFormPageState extends State<ActivityFormPage> {
  late final SuperadminActivityController _activityController;
  _ActivityFormLoadState _state = _ActivityFormLoadState.loading;
  ActivityFormController? _controller;

  bool get _isEditing => widget.activityId != null;

  @override
  void initState() {
    super.initState();
    _activityController = SuperadminActivityController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _controller?.dispose();
    _activityController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = _ActivityFormLoadState.loading);
    try {
      final options = await widget.repository.fetchFormOptions();
      final detail = _isEditing ? await widget.repository.fetchById(widget.activityId!) : null;
      if (!mounted) return;
      if (_isEditing && detail == null) {
        setState(() => _state = _ActivityFormLoadState.notFound);
        return;
      }
      _controller?.dispose();
      setState(() {
        _controller = _isEditing
            ? ActivityFormController.edit(options, detail!)
            : ActivityFormController.create(options);
        _state = _ActivityFormLoadState.ready;
      });
    } on ActivityDirectoryUnauthorizedException {
      if (mounted) {
        setState(() => _state = _ActivityFormLoadState.unauthorized);
      }
    } on Exception {
      if (mounted) setState(() => _state = _ActivityFormLoadState.failure);
    }
  }

  Future<bool> _confirmExit() async {
    final controller = _controller;
    if (controller == null || !controller.isDirty) return true;
    return await showDialog<bool>(
          context: context,
          barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
          builder: (context) => CoeloAdminDialogShell(
            dialogKey: const Key('activity-confirm-exit-dialog'),
            title: 'Sair sem salvar?',
            closeTooltip: 'Fechar confirmação',
            closeButtonKey: const Key('activity-dialog-close'),
            body: const Text('As alterações feitas nesta atividade serão descartadas.'),
            secondaryAction: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Continuar editando'),
            ),
            primaryAction: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sair sem salvar'),
            ),
          ),
        ) ??
        false;
  }

  Future<void> _requestCancel() async {
    if (await _confirmExit() && mounted) widget.onCancel();
  }

  Future<void> _selectDestination(String destination) async {
    if (await _confirmExit() && mounted) {
      widget.onDestinationSelected?.call(destination);
    }
  }

  Future<void> _submit() async {
    final controller = _controller!;
    if (!controller.validate()) return;
    controller.setSubmitting(true);
    controller.markSubmitted();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Protótipo visual — nenhuma alteração foi salva.')),
    );
    controller.setSubmitting(false);
    widget.onPrototypeSubmitted();
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    activityController: _activityController,
    title: _isEditing ? 'Editar atividade' : 'Criar atividade',
    subtitle: _isEditing
        ? 'Revise os dados demonstrativos desta atividade.'
        : 'Adicione uma nova atividade ao Coelo.',
    currentDestination: 'activities',
    showChatLauncher: false,
    onDestinationSelected: widget.onDestinationSelected == null ? null : _selectDestination,
    onBugReportSubmitted: widget.onBugReportSubmitted,
    child: _body(),
  );

  Widget _body() => switch (_state) {
    _ActivityFormLoadState.loading => const Center(child: CircularProgressIndicator()),
    _ActivityFormLoadState.notFound => CoeloStatePanel(
      title: 'Atividade não encontrada',
      message: 'O registro pode não existir ou não estar visível para sua conta.',
      icon: Icons.search_off_rounded,
      actionLabel: 'Voltar',
      onAction: widget.onCancel,
    ),
    _ActivityFormLoadState.failure => CoeloStatePanel(
      title: 'Não foi possível carregar o formulário',
      message: 'Tente novamente.',
      icon: Icons.cloud_off_outlined,
      actionLabel: 'Tentar novamente',
      onAction: _load,
    ),
    _ActivityFormLoadState.unauthorized => const CoeloStatePanel(
      title: 'Acesso não autorizado',
      message: 'Você não tem permissão para consultar os dados deste formulário.',
      icon: Icons.lock_outline_rounded,
    ),
    _ActivityFormLoadState.ready => _ActivityFormBody(
      controller: _controller!,
      onCancel: _requestCancel,
      onSubmit: _submit,
    ),
  };
}

final class _ActivityFormBody extends StatelessWidget {
  const _ActivityFormBody({
    required this.controller,
    required this.onCancel,
    required this.onSubmit,
  });

  final ActivityFormController controller;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => PopScope<void>(
      canPop: !controller.isDirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onCancel();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
              ? CoeloSpacing.space10
              : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space6
              : CoeloSpacing.space4;
          return Padding(
            padding: EdgeInsets.fromLTRB(inset, inset, inset, CoeloSpacing.space4),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('activity-form-scroll'),
                    padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 880),
                        child: Form(child: _ActivityFields(controller: controller)),
                      ),
                    ),
                  ),
                ),
                _ActivityFormFooter(controller: controller, onCancel: onCancel, onSubmit: onSubmit),
              ],
            ),
          );
        },
      ),
    ),
  );
}

final class _ActivityFields extends StatelessWidget {
  const _ActivityFields({required this.controller});

  final ActivityFormController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dados da atividade',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: CoeloSpacing.space1),
        Text(
          controller.isEditing
              ? 'Altere somente os campos confirmados pelo domínio.'
              : 'Informe a identidade e a unidade inicial da atividade.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: CoeloSpacing.space5),
        _ActivitySuggestions(controller: controller),
        const SizedBox(height: CoeloSpacing.space5),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
            final width = compact
                ? constraints.maxWidth
                : (constraints.maxWidth - CoeloSpacing.space3) / 2;
            final fields = <Widget>[
              CoeloFormTextField(
                fieldKey: const Key('activity-form-name'),
                controller: controller.name,
                labelText: 'Nome',
                hintText: 'Como a atividade aparece no Coelo',
                prefixIcon: Icons.badge_outlined,
                errorText: controller.nameError,
                textInputAction: TextInputAction.next,
              ),
              CoeloFormTextField(
                fieldKey: const Key('activity-form-description'),
                controller: controller.description,
                labelText: 'Descrição',
                hintText: 'Descreva o propósito da atividade',
                prefixIcon: Icons.notes_rounded,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
              ),
              if (!controller.isEditing) ...[
                CoeloAdminSingleSelectField<String>(
                  key: const Key('activity-form-institution'),
                  label: 'Instituição',
                  value: controller.selectedInstitutionId ?? '',
                  options: [
                    '',
                    ...controller.options.institutions.map((institution) => institution.id),
                  ],
                  optionLabel: (id) => id.isEmpty
                      ? 'Selecione a instituição'
                      : controller.options.institutions
                            .firstWhere((option) => option.id == id)
                            .name,
                  onChanged: controller.selectInstitution,
                  prefixIcon: Icons.apartment_outlined,
                  errorText: controller.institutionError,
                  searchable: true,
                  searchHintText: 'Buscar instituição',
                ),
                CoeloAdminSingleSelectField<String>(
                  key: const Key('activity-form-unit'),
                  label: 'Unidade inicial',
                  value: controller.selectedUnitId ?? '',
                  options: ['', ...controller.units.map((unit) => unit.id)],
                  optionLabel: (id) => id.isEmpty
                      ? 'Selecione a unidade'
                      : controller.units.firstWhere((option) => option.id == id).name,
                  onChanged: controller.selectUnit,
                  prefixIcon: Icons.business_outlined,
                  errorText: controller.unitError,
                  enabled: controller.selectedInstitutionId != null,
                  searchable: true,
                  searchHintText: 'Buscar unidade',
                ),
                _ActivityContextPreview(controller: controller),
              ] else
                _ActivityEditContext(detail: controller.detail!),
            ];
            return Wrap(
              spacing: CoeloSpacing.space3,
              runSpacing: CoeloSpacing.space4,
              children: [
                for (final field in fields)
                  SizedBox(
                    width: field is _ActivityEditContext || field is _ActivityContextPreview
                        ? constraints.maxWidth
                        : width,
                    child: field,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: CoeloSpacing.space5),
        _ActivityCommunicationPreviews(controller: controller),
      ],
    );
  }
}

final class _ActivitySuggestions extends StatelessWidget {
  const _ActivitySuggestions({required this.controller});

  final ActivityFormController controller;

  @override
  Widget build(BuildContext context) {
    const catalog = <String, Map<String, List<(String, String)>>>{
      'Acadêmicas': {
        'Linguagens': [
          ('Português', 'Leitura, escrita e comunicação em língua portuguesa.'),
          ('Inglês', 'Vivências e comunicação em língua inglesa.'),
        ],
        'Exatas': [
          ('Matemática', 'Raciocínio lógico e resolução de problemas.'),
          ('Robótica', 'Construção, programação e raciocínio lógico.'),
        ],
      },
      'Esportes': {
        'Aquáticos': [('Natação', 'Prática aquática orientada e segura.')],
        'Lutas': [('Judô', 'Disciplina, equilíbrio e prática corporal.')],
        'Campo': [('Futebol', 'Prática coletiva, coordenação e convivência.')],
      },
      'Artes': {
        'Visuais': [('Desenho', 'Expressão visual com diferentes técnicas.')],
      },
      'Natureza': {
        'Educação ambiental': [('Horta', 'Cuidado e educação ambiental.')],
      },
    };
    return Column(
      key: const Key('activity-suggestions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sugestões locais', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space3),
        for (final supercategory in catalog.entries) ...[
          Text(supercategory.key, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: CoeloSpacing.space2),
          for (final category in supercategory.value.entries) ...[
            Text(category.key, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: CoeloSpacing.space1),
            Wrap(
              spacing: CoeloSpacing.space2,
              runSpacing: CoeloSpacing.space2,
              children: [
                for (final suggestion in category.value)
                  ActionChip(
                    label: Text(suggestion.$1),
                    onPressed: () {
                      controller.name.text = suggestion.$1;
                      controller.description.text = suggestion.$2;
                    },
                  ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space2),
          ],
          const SizedBox(height: CoeloSpacing.space2),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            label: const Text('Outro'),
            onPressed: () {
              controller.name.clear();
              controller.description.clear();
            },
          ),
        ),
      ],
    );
  }
}

final class _ActivityCommunicationPreviews extends StatelessWidget {
  const _ActivityCommunicationPreviews({required this.controller});

  final ActivityFormController controller;

  @override
  Widget build(BuildContext context) {
    final activityName = controller.name.text.trim().isEmpty
        ? 'Nova atividade'
        : controller.name.text.trim();
    final groupName = controller.detail?.groups.firstOrNull?.name ?? 'selecionado';
    final publicationContext = 'Atividade $activityName · Grupo $groupName';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Recursos contextuais — prévia local', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space1),
        Text(
          'Estas ações são demonstrativas e não enviam mídia, mensagens ou publicações.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
            final width = compact
                ? constraints.maxWidth
                : (constraints.maxWidth - CoeloSpacing.space3 * 2) / 3;
            return Wrap(
              spacing: CoeloSpacing.space3,
              runSpacing: CoeloSpacing.space3,
              children: [
                SizedBox(
                  width: width,
                  child: const _ActivityPrototypePreview(
                    previewKey: Key('activity-photo-preview'),
                    icon: Icons.add_a_photo_outlined,
                    title: 'Foto da atividade',
                    description: 'Prévia sem upload ou mídia real.',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: const _ActivityPrototypePreview(
                    previewKey: Key('activity-conversation-preview'),
                    icon: Icons.forum_outlined,
                    title: 'Conversa',
                    description: 'Prévia do contexto de conversa, sem envio.',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _ActivityPrototypePreview(
                    previewKey: const Key('activity-publication-preview'),
                    icon: Icons.campaign_outlined,
                    title: 'Publicação',
                    description: publicationContext,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

final class _ActivityPrototypePreview extends StatelessWidget {
  const _ActivityPrototypePreview({
    required this.previewKey,
    required this.icon,
    required this.title,
    required this.description,
  });

  final Key previewKey;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
    key: previewKey,
    padding: const EdgeInsets.all(CoeloSpacing.space4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: CoeloSpacing.space2),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: CoeloSpacing.space1),
        Text(description),
      ],
    ),
  );
}

final class _ActivityContextPreview extends StatelessWidget {
  const _ActivityContextPreview({required this.controller});

  final ActivityFormController controller;

  @override
  Widget build(BuildContext context) {
    final institutionId = controller.selectedInstitutionId;
    final unitId = controller.selectedUnitId;
    final institution = institutionId == null || institutionId.isEmpty
        ? null
        : controller.options.institutions.firstWhere((option) => option.id == institutionId);
    final unit = unitId == null || unitId.isEmpty
        ? null
        : controller.options.units.firstWhere((option) => option.id == unitId);
    return Container(
      key: const Key('activity-context-preview'),
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_tree_outlined),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prévia contextual', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: CoeloSpacing.space1),
                Text(
                  institution == null
                      ? 'Escolha uma instituição e sua unidade inicial.'
                      : '${institution.name} → ${unit?.name ?? 'Selecione a unidade'}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _ActivityEditContext extends StatelessWidget {
  const _ActivityEditContext({required this.detail});

  final ActivityDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('activity-form-read-only-context'),
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Wrap(
        spacing: CoeloSpacing.space5,
        runSpacing: CoeloSpacing.space3,
        children: [
          _ContextValue(label: 'Instituição', value: detail.item.institutionName),
          _ContextValue(label: 'Origem', value: detail.item.origin.label),
          _ContextValue(
            label: 'Unidade de origem',
            value: detail.originUnitName ?? 'Não se aplica',
          ),
        ],
      ),
    );
  }
}

final class _ContextValue extends StatelessWidget {
  const _ContextValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: CoeloSpacing.space1),
          Text(value),
        ],
      ),
    ),
  );
}

final class _ActivityFormFooter extends StatelessWidget {
  const _ActivityFormFooter({
    required this.controller,
    required this.onCancel,
    required this.onSubmit,
  });

  final ActivityFormController controller;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final cancel = TextButton(
      key: const Key('activity-form-cancel'),
      onPressed: controller.isSubmitting ? null : onCancel,
      child: const Text('Cancelar'),
    );
    final submit = FilledButton(
      key: const Key('activity-form-submit'),
      onPressed: controller.isSubmitting ? null : onSubmit,
      child: controller.isSubmitting
          ? const SizedBox.square(
              dimension: CoeloSize.iconSm,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(controller.isEditing ? 'Salvar alterações' : 'Criar atividade'),
    );
    return SuperadminFormActionFooter(
      surfaceKey: const Key('activity-form-footer-surface'),
      tertiaryAction: cancel,
      continuationActions: [submit],
    );
  }
}
