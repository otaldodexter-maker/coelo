import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../app/activity/superadmin_activity.dart';
import '../../app/shell/superadmin_notice.dart';
import '../../app/shell/superadmin_shell.dart';
import '../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../auth/domain/logout_action.dart';
import 'daily_routine.dart';
import 'daily_routine_controller.dart';

final class DailyRoutineWizardPage extends StatefulWidget {
  const DailyRoutineWizardPage({
    required this.repository,
    required this.permissions,
    required this.logout,
    this.modelId,
    this.entryType = DailyRoutineEntryType.model,
    this.activityController,
    super.key,
  });

  final InMemoryDailyRoutineRepository repository;
  final DailyRoutinePermissions permissions;
  final LogoutAction logout;
  final String? modelId;
  final DailyRoutineEntryType entryType;
  final SuperadminActivityController? activityController;

  @override
  State<DailyRoutineWizardPage> createState() => _DailyRoutineWizardPageState();
}

final class _DailyRoutineWizardPageState extends State<DailyRoutineWizardPage> {
  static const groups = <String, String>{
    'group-a': 'Berçário A',
    'group-b': 'Maternal B',
    'group-c': 'Jardim C',
  };
  static const units = <String, String>{
    'unit-center': 'Unidade Centro',
    'unit-north': 'Unidade Norte',
  };
  static const activities = <String, List<String>>{
    'group-a': ['activity-meal', 'activity-sleep'],
    'group-b': ['activity-playground', 'activity-reading'],
    'group-c': ['activity-arts', 'activity-music'],
  };

  late final DailyRoutineFormController controller;
  late final TextEditingController name;
  late final TextEditingController description;
  double footerHeight = 0;

  bool get canManage => widget.permissions.canManage && !controller.isCoeloProvided;

  @override
  void initState() {
    super.initState();
    controller = DailyRoutineFormController(
      repository: widget.repository,
      permissions: widget.permissions,
      modelId: widget.modelId,
      entryType: widget.entryType,
    );
    name = TextEditingController(text: controller.name);
    description = TextEditingController(text: controller.description);
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> requestExit() async {
    if (!controller.isDirty) {
      await Navigator.of(context).maybePop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CoeloAdminDialogShell(
        title: 'Descartar alterações?',
        body: Text(
          controller.entryType == DailyRoutineEntryType.model
              ? 'As alterações locais deste modelo ainda não foram salvas.'
              : 'As alterações locais desta rotina ainda não foram salvas.',
        ),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Continuar editando'),
        ),
        primaryAction: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Descartar'),
        ),
      ),
    );
    if (leave == true && mounted) await Navigator.of(context).maybePop();
  }

  Future<void> save({required bool activate, bool finish = false}) async {
    final model = controller.save(activate: activate);
    showSuperadminNotice(
      context,
      model == null
          ? 'Revise as etapas indicadas antes de continuar.'
          : controller.entryType == DailyRoutineEntryType.model
          ? 'Modelo salvo localmente.'
          : activate
          ? 'Rotina ativada localmente.'
          : 'Rascunho salvo localmente.',
    );
    if (model != null && finish && mounted) {
      await Navigator.of(context).maybePop();
    }
  }

  Future<void> editSection([DailyRoutineSection? section]) async {
    final textController = TextEditingController(text: section?.name ?? '');
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CoeloAdminDialogShell(
          title: section == null ? 'Adicionar seção' : 'Editar seção',
          body: CoeloFormTextField(
            fieldKey: const Key('daily-routine-section-name'),
            controller: textController,
            labelText: 'Nome da seção',
            prefixIcon: Icons.view_agenda_outlined,
            errorText: error,
            onChanged: (_) {
              if (error != null) setDialogState(() => error = null);
            },
          ),
          secondaryAction: OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          primaryAction: FilledButton(
            key: const Key('daily-routine-section-save'),
            onPressed: () {
              if (textController.text.trim().isEmpty) {
                setDialogState(() => error = 'Informe o nome da seção.');
                return;
              }
              controller.upsertSection(sectionId: section?.id, name: textController.text);
              Navigator.pop(dialogContext);
            },
            child: const Text('Salvar seção'),
          ),
        ),
      ),
    );
  }

  Future<void> editField(DailyRoutineSection section, [DailyRoutineField? field]) async {
    const noInitialValue = '__no_initial_value__';
    final labelController = TextEditingController(text: field?.label ?? '');
    final initialController = TextEditingController(
      text:
          field?.type == DailyRoutineFieldType.singleChoice ||
              field?.type == DailyRoutineFieldType.multipleChoice
          ? ''
          : field?.initialValue?.toString() ?? '',
    );
    final optionsController = TextEditingController(text: field?.options.join(', ') ?? '');
    var type = field?.type ?? DailyRoutineFieldType.shortText;
    var required = field?.required ?? false;
    var selectedChoice = field?.initialValue is String ? field!.initialValue! as String : null;
    var selectedChoices = field?.initialValue is Iterable
        ? (field!.initialValue! as Iterable).map((value) => value.toString()).toSet()
        : <String>{};
    String? error;
    String? initialError;

    List<String> registeredOptions() => optionsController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final options = registeredOptions();
          final isSingleChoice = type == DailyRoutineFieldType.singleChoice;
          final isMultipleChoice = type == DailyRoutineFieldType.multipleChoice;
          return CoeloAdminDialogShell(
            title: field == null ? 'Adicionar campo' : 'Editar campo',
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CoeloFormTextField(
                  fieldKey: const Key('daily-routine-field-label'),
                  controller: labelController,
                  labelText: 'Nome do campo',
                  prefixIcon: Icons.label_outline_rounded,
                  errorText: error,
                  onChanged: (_) {
                    if (error != null) setDialogState(() => error = null);
                  },
                ),
                const SizedBox(height: CoeloSpacing.space3),
                CoeloAdminSingleSelectField<DailyRoutineFieldType>(
                  key: const Key('daily-routine-field-type'),
                  label: 'Tipo',
                  value: type,
                  options: DailyRoutineFieldType.values,
                  optionLabel: fieldTypeLabel,
                  onChanged: (value) => setDialogState(() {
                    type = value;
                    initialError = null;
                  }),
                ),
                if (isSingleChoice || isMultipleChoice) ...[
                  const SizedBox(height: CoeloSpacing.space3),
                  CoeloFormTextField(
                    fieldKey: const Key('daily-routine-field-options'),
                    controller: optionsController,
                    labelText: 'Opções separadas por vírgula',
                    prefixIcon: Icons.list_alt_rounded,
                    onChanged: (_) => setDialogState(() {
                      final currentOptions = registeredOptions();
                      if (selectedChoice != null && !currentOptions.contains(selectedChoice)) {
                        selectedChoice = null;
                        initialError = 'A opção inicial foi removida. Selecione um novo valor.';
                      }
                      if (!currentOptions.toSet().containsAll(selectedChoices)) {
                        selectedChoices = selectedChoices.intersection(currentOptions.toSet());
                        initialError = 'Uma opção inicial foi removida. Revise a seleção.';
                      }
                    }),
                  ),
                  const SizedBox(height: CoeloSpacing.space3),
                  if (options.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Cadastre ao menos uma opção para escolher o valor inicial.'),
                    )
                  else if (isSingleChoice)
                    CoeloAdminSingleSelectField<String>(
                      key: const Key('daily-routine-field-initial-choice'),
                      label: 'Valor inicial',
                      value: selectedChoice ?? noInitialValue,
                      options: [noInitialValue, ...options],
                      optionLabel: (value) => value == noInitialValue ? 'Sem valor inicial' : value,
                      searchable: false,
                      onChanged: (value) => setDialogState(() {
                        selectedChoice = value == noInitialValue ? null : value;
                        initialError = null;
                      }),
                    )
                  else
                    CoeloAdminMultiSelectField<String>(
                      key: const Key('daily-routine-field-initial-choices'),
                      label: 'Valores iniciais',
                      options: options,
                      selectedValues: selectedChoices,
                      optionLabel: (value) => value,
                      searchable: false,
                      onChanged: (values) => setDialogState(() {
                        selectedChoices = values;
                        initialError = null;
                      }),
                    ),
                  if (initialError != null) ...[
                    const SizedBox(height: CoeloSpacing.space2),
                    Semantics(
                      liveRegion: true,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          initialError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: CoeloSpacing.space3),
                CoeloAdminSingleSelectField<bool>(
                  label: 'Obrigatoriedade',
                  value: required,
                  options: const [false, true],
                  optionLabel: (value) => value ? 'Obrigatório' : 'Opcional',
                  onChanged: (value) => setDialogState(() => required = value),
                ),
                if (!isSingleChoice && !isMultipleChoice) ...[
                  const SizedBox(height: CoeloSpacing.space3),
                  CoeloFormTextField(
                    fieldKey: const Key('daily-routine-field-initial-value'),
                    controller: initialController,
                    labelText: 'Valor inicial (opcional)',
                    prefixIcon: Icons.auto_awesome_outlined,
                  ),
                ],
                const SizedBox(height: CoeloSpacing.space2),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('O valor inicial preenche somente campos vazios.'),
                ),
              ],
            ),
            secondaryAction: OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            primaryAction: FilledButton(
              key: const Key('daily-routine-field-save'),
              onPressed: () {
                if (labelController.text.trim().isEmpty) {
                  setDialogState(() => error = 'Informe o nome do campo.');
                  return;
                }
                final currentOptions = registeredOptions();
                if ((isSingleChoice || isMultipleChoice) && currentOptions.isEmpty) {
                  setDialogState(() => initialError = 'Cadastre ao menos uma opção.');
                  return;
                }
                if (initialError != null) return;
                controller.upsertField(
                  sectionId: section.id,
                  fieldId: field?.id,
                  label: labelController.text,
                  type: type,
                  required: required,
                  initialValue: isSingleChoice
                      ? selectedChoice
                      : isMultipleChoice
                      ? selectedChoices.isEmpty
                            ? null
                            : selectedChoices.toList(growable: false)
                      : initialController.text.trim().isEmpty
                      ? null
                      : initialController.text.trim(),
                  options: currentOptions,
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Salvar campo'),
            ),
          );
        },
      ),
    );
  }

  Future<void> editVariation(DailyRoutineScope scope) async {
    final fields = controller.sections.expand((section) => section.fields).toList();
    if (fields.isEmpty) {
      showSuperadminNotice(context, 'Adicione campos ao modelo-base antes de criar variações.');
      return;
    }
    var field = fields.first;
    var required = scope.fieldOverrides[field.id]?.required ?? field.required;
    final initialController = TextEditingController(
      text: scope.fieldOverrides[field.id]?.initialValue?.toString() ?? '',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CoeloAdminDialogShell(
          title: 'Variação de ${groups[scope.groupId] ?? scope.groupId}',
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ajuste somente o que difere do modelo-base nesta turma.'),
              if (scope.fieldOverrides.containsKey(field.id))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('daily-routine-variation-reset'),
                    onPressed: () {
                      controller.removeScopeFieldOverride(scope.groupId, field.id);
                      Navigator.pop(dialogContext);
                    },
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('Reverter para o modelo-base'),
                  ),
                ),
              const SizedBox(height: CoeloSpacing.space3),
              CoeloAdminSingleSelectField<DailyRoutineField>(
                label: 'Campo do modelo-base',
                value: field,
                options: fields,
                optionLabel: (value) => value.label,
                onChanged: (value) {
                  setDialogState(() {
                    field = value;
                    required = scope.fieldOverrides[value.id]?.required ?? value.required;
                    initialController.text =
                        scope.fieldOverrides[value.id]?.initialValue?.toString() ?? '';
                  });
                },
              ),
              const SizedBox(height: CoeloSpacing.space3),
              CoeloAdminSingleSelectField<bool>(
                label: 'Obrigatoriedade nesta turma',
                value: required,
                options: const [false, true],
                optionLabel: (value) => value ? 'Obrigatório' : 'Opcional',
                onChanged: (value) => setDialogState(() => required = value),
              ),
              const SizedBox(height: CoeloSpacing.space3),
              CoeloFormTextField(
                fieldKey: const Key('daily-routine-variation-initial-value'),
                controller: initialController,
                labelText: 'Valor inicial nesta turma (opcional)',
                prefixIcon: Icons.tune_rounded,
              ),
            ],
          ),
          secondaryAction: OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          primaryAction: FilledButton(
            key: const Key('daily-routine-variation-save'),
            onPressed: () {
              controller.setScopeFieldOverride(
                scope.groupId,
                DailyRoutineFieldOverride(
                  fieldId: field.id,
                  required: required,
                  initialValue: initialController.text.trim().isEmpty
                      ? null
                      : initialController.text.trim(),
                ),
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Salvar variação'),
          ),
        ),
      ),
    );
  }

  Future<void> addLocalVariationField(DailyRoutineScope scope) async {
    final labelController = TextEditingController();
    var type = DailyRoutineFieldType.shortText;
    var required = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CoeloAdminDialogShell(
          title: 'Adicionar campo desta turma',
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Este campo complementa a base somente nesta turma.'),
              const SizedBox(height: CoeloSpacing.space3),
              CoeloFormTextField(
                fieldKey: const Key('daily-routine-local-field-label'),
                controller: labelController,
                labelText: 'Nome do campo',
                prefixIcon: Icons.label_outline_rounded,
                errorText: error,
                onChanged: (_) {
                  if (error != null) setDialogState(() => error = null);
                },
              ),
              const SizedBox(height: CoeloSpacing.space3),
              CoeloAdminSingleSelectField<DailyRoutineFieldType>(
                label: 'Tipo',
                value: type,
                options: DailyRoutineFieldType.values,
                optionLabel: fieldTypeLabel,
                onChanged: (value) => setDialogState(() => type = value),
              ),
              const SizedBox(height: CoeloSpacing.space3),
              CoeloAdminSingleSelectField<bool>(
                label: 'Obrigatoriedade',
                value: required,
                options: const [false, true],
                optionLabel: (value) => value ? 'Obrigatório' : 'Opcional',
                onChanged: (value) => setDialogState(() => required = value),
              ),
            ],
          ),
          secondaryAction: OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          primaryAction: FilledButton(
            key: const Key('daily-routine-local-field-save'),
            onPressed: () {
              if (labelController.text.trim().isEmpty) {
                setDialogState(() => error = 'Informe o nome do campo.');
                return;
              }
              controller.addScopeLocalField(
                scope.groupId,
                label: labelController.text,
                type: type,
                required: required,
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Adicionar campo'),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final creating = widget.modelId == null;
    return SuperadminShell(
      logout: widget.logout,
      currentDestination: 'daily-routine',
      title: creating
          ? controller.entryType == DailyRoutineEntryType.model
                ? 'Criar modelo'
                : 'Nova rotina'
          : controller.isCoeloProvided
          ? 'Visualizar modelo'
          : controller.entryType == DailyRoutineEntryType.model
          ? 'Editar modelo'
          : 'Editar rotina',
      subtitle: controller.isCoeloProvided
          ? 'Modelo inicial fornecido pelo Coelo. Duplique para personalizar.'
          : controller.entryType == DailyRoutineEntryType.model
          ? 'Configure uma base reutilizável.'
          : 'Configure o registro cotidiano efetivamente utilizado.',
      activityController: widget.activityController,
      chatLauncherBottomInset: footerHeight == 0 ? 0 : footerHeight + CoeloSpacing.space4,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        key: const Key('daily-routine-page-surface'),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) => PopScope<void>(
            canPop: !controller.isDirty,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) requestExit();
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth;
                final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
                    ? CoeloSpacing.space10
                    : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                    ? CoeloSpacing.space6
                    : CoeloSpacing.space4;
                final nav = navigation();
                final content = Expanded(
                  child: Column(
                    children: [
                      if (!side) ...[nav, const SizedBox(height: CoeloSpacing.space4)],
                      Expanded(
                        child: SingleChildScrollView(
                          key: const Key('daily-routine-editor-scroll'),
                          padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 880),
                              child: AnimatedSwitcher(
                                duration: MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : CoeloMotion.short,
                                child: KeyedSubtree(
                                  key: ValueKey(controller.currentStep),
                                  child: currentSection(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      footer(),
                    ],
                  ),
                );
                return Padding(
                  padding: EdgeInsets.fromLTRB(inset, inset, inset, CoeloSpacing.space4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (side) ...[nav, const SizedBox(width: CoeloSpacing.space6)],
                      content,
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget navigation() => SuperadminFormStepNavigation(
    steps: [
      for (final step in DailyRoutineFormStep.values)
        SuperadminFormStep(label: stepLabel(step), status: stepStatus(step)),
    ],
    currentIndex: controller.currentStep.index,
    onStepSelected: (index) => controller.goToStep(DailyRoutineFormStep.values[index]),
  );

  SuperadminFormStepStatus stepStatus(DailyRoutineFormStep step) {
    if (controller.stepHasError(step)) return SuperadminFormStepStatus.error;
    if (step == controller.currentStep) return SuperadminFormStepStatus.current;
    return step.index < controller.currentStep.index
        ? SuperadminFormStepStatus.complete
        : SuperadminFormStepStatus.incomplete;
  }

  Widget footer() {
    final last = controller.currentStep == DailyRoutineFormStep.reviewAndActivation;
    return SuperadminFormActionFooter(
      surfaceKey: const Key('daily-routine-form-footer'),
      onHeightChanged: (height) {
        if ((footerHeight - height).abs() >= 0.5) setState(() => footerHeight = height);
      },
      tertiaryAction: TextButton(
        key: const Key('daily-routine-cancel'),
        onPressed: requestExit,
        child: const Text('Cancelar'),
      ),
      continuationActions: [
        if (controller.currentStep.index > 0)
          OutlinedButton(
            key: const Key('daily-routine-previous'),
            onPressed: controller.previousStep,
            child: const Text('Anterior'),
          ),
        if (!last)
          OutlinedButton(
            key: const Key('daily-routine-continue'),
            onPressed: canManage ? controller.continueFromCurrentStep : null,
            child: const Text('Continuar'),
          ),
        if (last && widget.modelId == null && controller.entryType == DailyRoutineEntryType.routine)
          OutlinedButton(
            key: const Key('daily-routine-save-draft'),
            onPressed: canManage ? () => save(activate: false) : null,
            child: const Text('Salvar rascunho'),
          ),
        if (last)
          FilledButton(
            key: const Key('daily-routine-save'),
            onPressed:
                canManage &&
                    (controller.status == DailyRoutineStatus.draft || controller.canActivate)
                ? () => save(activate: controller.status == DailyRoutineStatus.active, finish: true)
                : null,
            child: Text(
              widget.modelId != null
                  ? 'Salvar alterações'
                  : controller.entryType == DailyRoutineEntryType.model
                  ? 'Criar modelo'
                  : controller.status == DailyRoutineStatus.active
                  ? 'Ativar rotina'
                  : 'Criar rotina',
            ),
          ),
      ],
    );
  }

  Widget currentSection() => switch (controller.currentStep) {
    DailyRoutineFormStep.identity => identitySection(),
    DailyRoutineFormStep.scope => scopeSection(),
    DailyRoutineFormStep.sectionsAndFields => fieldsSection(),
    DailyRoutineFormStep.reviewAndActivation => reviewSection(),
  };

  Widget header(String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: CoeloSpacing.space2),
        Text(text),
        if (!canManage)
          Text(
            controller.isCoeloProvided
                ? 'Modelo Coelo somente para consulta'
                : 'Modo somente leitura',
          ),
      ],
    ),
  );

  Widget identitySection() => Column(
    key: const Key('daily-routine-step-identity'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      header(
        'Identidade',
        controller.entryType == DailyRoutineEntryType.model
            ? 'O modelo define uma base reutilizável para novas rotinas.'
            : 'A rotina é o objeto utilizado no registro cotidiano.',
      ),
      CoeloFormTextField(
        fieldKey: const Key('daily-routine-name'),
        controller: name,
        labelText: 'Nome',
        prefixIcon: Icons.edit_note_rounded,
        enabled: canManage,
        errorText: controller.stepHasError(DailyRoutineFormStep.identity)
            ? controller.entryType == DailyRoutineEntryType.model
                  ? 'Informe o nome do modelo.'
                  : 'Informe o nome da rotina.'
            : null,
        onChanged: controller.updateName,
      ),
      const SizedBox(height: CoeloSpacing.space3),
      CoeloFormTextField(
        fieldKey: const Key('daily-routine-description'),
        controller: description,
        labelText: 'Descrição',
        prefixIcon: Icons.notes_rounded,
        enabled: canManage,
        maxLines: 3,
        onChanged: controller.updateDescription,
      ),
      const SizedBox(height: CoeloSpacing.space3),
      CoeloAdminSingleSelectField<DailyRoutineOrigin>(
        label: 'Origem do modelo',
        value: controller.origin,
        options: DailyRoutineOrigin.values,
        optionLabel: originLabel,
        enabled: canManage,
        onChanged: controller.updateOrigin,
      ),
      const SizedBox(height: CoeloSpacing.space3),
      if (controller.origin == DailyRoutineOrigin.unit) ...[
        CoeloAdminSingleSelectField<String>(
          key: const Key('daily-routine-origin-unit'),
          label: 'Unidade de origem',
          value: controller.originUnitId ?? units.keys.first,
          options: units.keys.toList(),
          optionLabel: (value) => units[value] ?? value,
          enabled: canManage,
          searchable: false,
          onChanged: controller.updateOriginUnit,
        ),
        const SizedBox(height: CoeloSpacing.space3),
      ],
      CoeloAdminSingleSelectField<DailyRoutineStatus>(
        label: 'Estado',
        value: controller.status,
        options: DailyRoutineStatus.values,
        optionLabel: statusLabel,
        enabled: canManage,
        onChanged: controller.updateStatus,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      info(
        'Política do modelo',
        'Mudanças opcionais preservam variações locais; mudanças obrigatórias seguem as regras existentes.',
      ),
    ],
  );

  Widget scopeSection() => Column(
    key: const Key('daily-routine-step-scope'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      header('Alcance', 'Atividades apenas refinam o contexto dentro de cada turma.'),
      CoeloAdminMultiSelectField<String>(
        key: const Key('daily-routine-groups'),
        label: 'Turmas vinculadas',
        options: groups.keys.toList(),
        selectedValues: controller.selectedGroupIds,
        optionLabel: (id) => groups[id] ?? id,
        enabled: canManage,
        searchable: false,
        onChanged: controller.updateSelectedGroups,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      if (controller.scopes.isEmpty)
        info(
          'Nenhuma turma vinculada',
          'Selecione uma ou mais turmas para distribuir o modelo-base.',
        )
      else
        for (final scope in controller.scopes) ...[
          CoeloAdminInteractiveCard(
            child: Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    groups[scope.groupId] ?? scope.groupId,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text('Herda a base e mantém ajustes como variação contextual.'),
                  const SizedBox(height: CoeloSpacing.space3),
                  CoeloAdminMultiSelectField<String>(
                    label: 'Atividades que refinam o alcance',
                    options: activities[scope.groupId] ?? const [],
                    selectedValues: scope.activityIds,
                    optionLabel: activityLabel,
                    enabled: canManage,
                    searchable: false,
                    emptyLabel: 'Todas as atividades',
                    onChanged: (values) => controller.updateGroupActivities(scope.groupId, values),
                  ),
                  const SizedBox(height: CoeloSpacing.space3),
                  Text(
                    scope.fieldOverrides.isEmpty
                        ? 'Sem variações locais'
                        : '${scope.fieldOverrides.length} variação(ões) local(is)',
                  ),
                  if (scope.fieldOverrides.isNotEmpty) ...[
                    const SizedBox(height: CoeloSpacing.space2),
                    for (final override in scope.fieldOverrides.values)
                      Text(
                        '• ${_fieldLabel(override.fieldId)} — ${override.required == true ? 'obrigatório' : 'opcional'}${override.initialValue == null ? '' : ' — inicial: ${override.initialValue}'}',
                      ),
                  ],
                  if (scope.localSections.isNotEmpty) ...[
                    const SizedBox(height: CoeloSpacing.space2),
                    for (final localField in scope.localSections.expand(
                      (section) => section.fields,
                    ))
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Campo local: ${localField.label} — ${fieldTypeLabel(localField.type)}',
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remover campo local ${localField.label}',
                            onPressed: canManage
                                ? () =>
                                      controller.removeScopeLocalField(scope.groupId, localField.id)
                                : null,
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                  ],
                  const SizedBox(height: CoeloSpacing.space3),
                  Wrap(
                    spacing: CoeloSpacing.space2,
                    runSpacing: CoeloSpacing.space2,
                    children: [
                      OutlinedButton.icon(
                        key: Key('daily-routine-scope-${scope.groupId}-variation'),
                        onPressed: canManage ? () => editVariation(scope) : null,
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Configurar variação'),
                      ),
                      OutlinedButton.icon(
                        key: Key('daily-routine-scope-${scope.groupId}-local-field'),
                        onPressed: canManage ? () => addLocalVariationField(scope) : null,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Adicionar campo local'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space3),
        ],
    ],
  );

  String _fieldLabel(String fieldId) {
    for (final section in controller.sections) {
      for (final field in section.fields) {
        if (field.id == fieldId) return field.label;
      }
    }
    return fieldId;
  }

  Widget fieldsSection() => Column(
    key: const Key('daily-routine-step-fields'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      header('Seções e campos', 'Valores iniciais preenchem somente campos vazios.'),
      for (var index = 0; index < controller.sections.length; index++) ...[
        sectionCard(controller.sections[index], index),
        const SizedBox(height: CoeloSpacing.space3),
      ],
      if (controller.sections.isEmpty)
        info('Nenhuma seção configurada', 'Adicione a primeira seção para definir os campos.'),
      const SizedBox(height: CoeloSpacing.space3),
      OutlinedButton.icon(
        key: const Key('daily-routine-add-section'),
        onPressed: canManage ? editSection : null,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar seção'),
      ),
      const SizedBox(height: CoeloSpacing.space4),
      Wrap(
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: [
          for (final type in DailyRoutineFieldType.values) Chip(label: Text(fieldTypeLabel(type))),
        ],
      ),
    ],
  );

  Widget sectionCard(DailyRoutineSection section, int index) => CoeloAdminInteractiveCard(
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${index + 1}. ${section.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Editar seção',
                onPressed: canManage ? () => editSection(section) : null,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Remover seção',
                color: Theme.of(context).colorScheme.error,
                onPressed: canManage ? () => controller.removeSection(section.id) : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          if (section.fields.isEmpty)
            const Text('Nenhum campo nesta seção.')
          else
            for (var fieldIndex = 0; fieldIndex < section.fields.length; fieldIndex++)
              Padding(
                padding: const EdgeInsets.only(top: CoeloSpacing.space2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${fieldIndex + 1}. ${section.fields[fieldIndex].label} • ${fieldTypeLabel(section.fields[fieldIndex].type)}${section.fields[fieldIndex].required ? ' • Obrigatório' : ' • Opcional'}${section.fields[fieldIndex].initialValue == null ? '' : ' • Inicial: ${section.fields[fieldIndex].initialValue}'}${section.fields[fieldIndex].options.isEmpty ? '' : ' • Opções: ${section.fields[fieldIndex].options.join(', ')}'}',
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar campo ${section.fields[fieldIndex].label}',
                      onPressed: canManage
                          ? () => editField(section, section.fields[fieldIndex])
                          : null,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Remover campo ${section.fields[fieldIndex].label}',
                      color: Theme.of(context).colorScheme.error,
                      onPressed: canManage
                          ? () => controller.removeField(section.id, section.fields[fieldIndex].id)
                          : null,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: CoeloSpacing.space3),
          OutlinedButton.icon(
            key: Key('daily-routine-section-${section.id}-add-field'),
            onPressed: canManage ? () => editField(section) : null,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar campo'),
          ),
        ],
      ),
    ),
  );

  Widget reviewSection() {
    final fields = controller.sections.expand((section) => section.fields).toList();
    final requiredCount = fields.where((field) => field.required).length;
    final initialCount = fields.where((field) => field.initialValue != null).length;
    final variationCount = controller.scopes.fold<int>(
      0,
      (total, scope) => total + scope.fieldOverrides.length,
    );
    final localFieldCount = controller.scopes.fold<int>(
      0,
      (total, scope) => total + scope.localSections.expand((section) => section.fields).length,
    );
    final activityLines = controller.scopes
        .where((scope) => scope.activityIds.isNotEmpty)
        .map(
          (scope) =>
              '${groups[scope.groupId] ?? scope.groupId}: ${scope.activityIds.map(activityLabel).join(', ')}',
        )
        .toList();
    return Column(
      key: const Key('daily-routine-step-review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header(
          'Revisão e ativação',
          'Confira o modelo e volte à etapa correspondente para ajustar.',
        ),
        review('Identidade', [
          controller.name.isEmpty ? 'Nome não informado' : controller.name,
          controller.description.trim().isEmpty ? 'Sem descrição' : controller.description,
          'Origem: ${originLabel(controller.origin)}',
          if (controller.origin == DailyRoutineOrigin.unit)
            'Unidade: ${units[controller.originUnitId] ?? controller.originUnitId}',
          'Estado escolhido: ${statusLabel(controller.status)}',
          'Política: atualizações opcionais preservam variações locais; mudanças obrigatórias seguem compatibilidade e conflito existentes.',
        ], DailyRoutineFormStep.identity),
        review('Alcance', [
          controller.selectedGroupIds.isEmpty
              ? 'Nenhuma turma vinculada'
              : 'Turmas: ${controller.selectedGroupIds.map((id) => groups[id] ?? id).join(', ')}',
          if (activityLines.isEmpty) 'Sem refinamento por atividade' else ...activityLines,
          variationCount == 0
              ? 'Sem variações por turma'
              : '$variationCount variação(ões) por turma',
          if (localFieldCount > 0) '$localFieldCount campo(s) adicional(is) por turma',
          for (final scope in controller.scopes)
            if (scope.fieldOverrides.isNotEmpty || scope.localSections.isNotEmpty)
              '${groups[scope.groupId] ?? scope.groupId}: '
                  '${scope.fieldOverrides.values.map((override) => _fieldLabel(override.fieldId)).join(', ')}'
                  '${scope.localSections.isEmpty ? '' : '${scope.fieldOverrides.isEmpty ? '' : '; '}locais: ${scope.localSections.expand((section) => section.fields).map((field) => field.label).join(', ')}'}',
        ], DailyRoutineFormStep.scope),
        review('Seções e campos', [
          '${controller.sections.length} seções',
          '${fields.length} campos',
          '$requiredCount obrigatórios',
          '$initialCount com valor inicial',
          for (final field in fields.where((field) => field.required))
            'Obrigatório: ${field.label}',
          for (final field in fields.where((field) => field.initialValue != null))
            'Inicial: ${field.label} = ${field.initialValue}',
        ], DailyRoutineFormStep.sectionsAndFields),
        review(
          'Pendências e ativação',
          [
            if (controller.name.trim().isEmpty)
              controller.entryType == DailyRoutineEntryType.model
                  ? 'Informe o nome do modelo'
                  : 'Informe o nome da rotina',
            if (controller.scopes.isEmpty) 'Vincule ao menos uma turma',
            if (!controller.sections.any((section) => section.fields.isNotEmpty))
              'Adicione ao menos um campo',
            if (controller.updateAvailable)
              'Há uma atualização opcional disponível; a variação local foi preservada.',
            if (widget.repository.archivedConflicts.isNotEmpty)
              '${widget.repository.archivedConflicts.length} conflito(s) arquivado(s) para revisão.',
            if (controller.canActivate)
              controller.status == DailyRoutineStatus.active
                  ? 'Pronta para permanecer ativa'
                  : 'Pronta para ativação',
          ],
          controller.scopes.isEmpty
              ? DailyRoutineFormStep.scope
              : !controller.sections.any((section) => section.fields.isNotEmpty)
              ? DailyRoutineFormStep.sectionsAndFields
              : DailyRoutineFormStep.identity,
        ),
      ],
    );
  }

  Widget review(String title, List<String> lines, DailyRoutineFormStep destination) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
    child: CoeloAdminInteractiveCard(
      semanticLabel: 'Revisar $title',
      onPressed: () => controller.goToStep(destination),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: CoeloSpacing.space2),
            for (final line in lines) Text(line),
          ],
        ),
      ),
    ),
  );

  Widget info(String title, String text) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: CoeloSpacing.space1),
          Text(text),
        ],
      ),
    );
  }
}

String stepLabel(DailyRoutineFormStep step) => switch (step) {
  DailyRoutineFormStep.identity => 'Identidade',
  DailyRoutineFormStep.scope => 'Alcance',
  DailyRoutineFormStep.sectionsAndFields => 'Seções e campos',
  DailyRoutineFormStep.reviewAndActivation => 'Revisão e ativação',
};

String originLabel(DailyRoutineOrigin value) => switch (value) {
  DailyRoutineOrigin.institution => 'Instituição',
  DailyRoutineOrigin.unit => 'Unidade',
};

String activityLabel(String value) => switch (value) {
  'activity-meal' => 'Refeição',
  'activity-sleep' => 'Sono',
  'activity-playground' => 'Parque',
  'activity-reading' => 'Leitura',
  'activity-arts' => 'Artes',
  'activity-music' => 'Música',
  _ => value,
};

String statusLabel(DailyRoutineStatus value) => switch (value) {
  DailyRoutineStatus.draft => 'Rascunho',
  DailyRoutineStatus.active => 'Ativo',
};

String fieldTypeLabel(DailyRoutineFieldType value) => switch (value) {
  DailyRoutineFieldType.shortText => 'Texto curto',
  DailyRoutineFieldType.longText => 'Texto longo',
  DailyRoutineFieldType.singleChoice => 'Escolha única',
  DailyRoutineFieldType.multipleChoice => 'Escolha múltipla',
  DailyRoutineFieldType.number => 'Número',
  DailyRoutineFieldType.boolean => 'Sim/Não',
};
