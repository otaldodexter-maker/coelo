import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../../auth/domain/logout_action.dart';
import '../../institutions/presentation/widgets/institution_logo_picker_stub.dart'
    if (dart.library.html) '../../institutions/presentation/widgets/institution_logo_picker_web.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/activity_directory.dart';
import '../../units/domain/unit_handle_availability.dart';
import '../domain/activity_profile_about_repository.dart';
import 'activity_form_controller.dart';
import 'activity_form_draft.dart';
import 'activity_form_sections.dart';

typedef ActivityFormSubmit = Future<void> Function(ActivityFormDraft draft);
typedef ActivityLocationSelectionBuilder =
    Widget Function(BuildContext context, ActivityFormController controller);
typedef ActivityLocationCreator =
    Future<List<ActivityFormLocationOption>> Function(ActivityLocationDraft draft);

enum _ActivityFormLoadState { loading, ready, notFound, failure, unauthorized }

enum _ActivityFormCommand { saveDraft, submit }

final class ActivityFormPage extends StatefulWidget {
  const ActivityFormPage({
    required this.repository,
    this.checkHandleAvailability,
    this.setHandle,
    required this.logout,
    required this.onCancel,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onCreateLocation,
    this.locationSelectionBuilder,
    this.activityId,
    this.initialInstitutionId,
    this.initialUnitId,
    this.initialTemplateId,
    this.initialDraft,
    this.initialStep,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    this.imagePicker,
    this.aboutRepository = const UnavailableActivityProfileAboutRepository(),
    super.key,
  });

  final String? activityId;
  final String? initialInstitutionId;
  final String? initialUnitId;
  final String? initialTemplateId;
  final ActivityFormDraft? initialDraft;
  final ActivityFormStep? initialStep;
  final ActivityDirectoryRepository repository;

  /// Regra do @ (ADR 0034 Decisao 16): disponibilidade do stem enquanto digita.
  final StructureHandleAvailabilityChecker? checkHandleAvailability;
  final StructureHandleSetter? setHandle;
  final LogoutAction logout;
  final VoidCallback onCancel;
  final ActivityFormSubmit onSaveDraft;
  final ActivityFormSubmit onSubmit;
  final ActivityLocationCreator onCreateLocation;
  final ActivityLocationSelectionBuilder? locationSelectionBuilder;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final InstitutionLogoPicker? imagePicker;
  final ActivityProfileAboutRepository aboutRepository;

  @override
  State<ActivityFormPage> createState() => _ActivityFormPageState();
}

final class _ActivityFormPageState extends State<ActivityFormPage> {
  late final SuperadminActivityController _activityController;
  _ActivityFormLoadState _state = _ActivityFormLoadState.loading;
  double _footerHeight = 0;
  ActivityFormController? _controller;
  _ActivityFormCommand? _failedCommand;
  var _loadGeneration = 0;
  var _commandGeneration = 0;
  _ActivityFormAttempt? _pendingAttempt;

  bool get _isEditing => widget.activityId != null;

  @override
  void initState() {
    super.initState();
    _activityController = SuperadminActivityController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant ActivityFormPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityId == widget.activityId &&
        oldWidget.initialInstitutionId == widget.initialInstitutionId &&
        oldWidget.initialUnitId == widget.initialUnitId &&
        identical(oldWidget.repository, widget.repository)) {
      return;
    }
    _controller?.dispose();
    _controller = null;
    _failedCommand = null;
    _pendingAttempt = null;
    _state = _ActivityFormLoadState.loading;
    _loadGeneration++;
    _commandGeneration++;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _loadGeneration++;
    _commandGeneration++;
    _controller?.dispose();
    _activityController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    final repository = widget.repository;
    final activityId = widget.activityId;
    final initialInstitutionId = widget.initialInstitutionId;
    final initialUnitId = widget.initialUnitId;
    final initialTemplateId = widget.initialTemplateId;
    final initialDraft = widget.initialDraft;
    final initialStep = widget.initialStep;
    final isEditing = activityId != null;
    setState(() => _state = _ActivityFormLoadState.loading);
    try {
      final detail = isEditing ? await repository.fetchById(activityId) : null;
      if (!_isCurrentLoad(generation, repository, activityId)) return;
      if (isEditing && detail == null) {
        setState(() => _state = _ActivityFormLoadState.notFound);
        return;
      }
      ActivityFormOptions options;
      String? initialCatalogError;
      if (isEditing) {
        // A form_options_v2 nao devolve taxonomia nem modelos; sem a arvore o
        // controller nao consegue hidratar a categoria e o roteador recusa
        // salvar. O catalogo entra pela mesma chamada que a criacao usa.
        final institutionId = detail!.item.institutionId;
        final scoped = await repository.fetchFormOptions(institutionId: institutionId);
        ActivityTemplateOptions catalog;
        try {
          catalog = await repository.fetchTemplateOptions(institutionId: institutionId);
        } on ActivityDirectoryUnauthorizedException {
          rethrow;
        } on Exception {
          catalog = const ActivityTemplateOptions();
          initialCatalogError = 'Não foi possível carregar categorias e modelos.';
        }
        options = ActivityFormOptions(
          institutions: catalog.institutions,
          units: scoped.units,
          locations: scoped.locations,
          groups: scoped.groups,
          professionals: scoped.professionals,
          students: scoped.students,
          taxonomy: catalog.taxonomy,
          templates: catalog.templates,
        );
      } else if (initialInstitutionId != null) {
        options = await repository.fetchFormOptions(institutionId: initialInstitutionId);
      } else {
        try {
          options = _formOptionsFromTemplates(await repository.fetchTemplateOptions());
        } on ActivityDirectoryUnauthorizedException {
          rethrow;
        } on Exception {
          ActivityFilterOptions filters;
          try {
            filters = await repository.fetchFilterOptions();
          } on ActivityDirectoryUnauthorizedException {
            rethrow;
          } on Exception {
            filters = const ActivityFilterOptions();
          }
          options = ActivityFormOptions(
            institutions: filters.institutions
                .map((item) => ActivityFormInstitutionOption(id: item.id, name: item.label))
                .toList(growable: false),
          );
          initialCatalogError = 'Não foi possível carregar categorias e modelos.';
        }
      }
      if (!_isCurrentLoad(generation, repository, activityId)) return;
      _controller?.dispose();
      final nextController = isEditing
          ? ActivityFormController.edit(
              options,
              detail!,
              initialDraft: initialDraft,
              initialCatalogError: initialCatalogError,
              loadTemplateOptions: (institutionId) =>
                  repository.fetchTemplateOptions(institutionId: institutionId),
              handleAvailabilityChecker: widget.checkHandleAvailability,
              handleSetter: widget.setHandle,
              professionalSearcher: (institutionId, query) =>
                  repository.searchProfessionals(institutionId: institutionId, query: query),
            )
          : ActivityFormController.create(
              options,
              initialInstitutionId: initialInstitutionId,
              initialUnitId: initialUnitId,
              initialTemplateId: initialTemplateId,
              loadScopedOptions: (institutionId) =>
                  repository.fetchFormOptions(institutionId: institutionId),
              loadTemplateOptions: (institutionId) =>
                  repository.fetchTemplateOptions(institutionId: institutionId),
              initialCatalogError: initialCatalogError,
              professionalSearcher: (institutionId, query) =>
                  repository.searchProfessionals(institutionId: institutionId, query: query),
              handleAvailabilityChecker: widget.checkHandleAvailability,
            );
      if (initialStep case final step?) {
        nextController.goToStep(step.index);
      }
      if (!_isCurrentLoad(generation, repository, activityId)) {
        nextController.dispose();
        return;
      }
      setState(() {
        _controller = nextController;
        _state = _ActivityFormLoadState.ready;
      });
    } on ActivityDirectoryUnauthorizedException {
      if (_isCurrentLoad(generation, repository, activityId)) {
        setState(() => _state = _ActivityFormLoadState.unauthorized);
      }
    } on Exception {
      if (_isCurrentLoad(generation, repository, activityId)) {
        setState(() => _state = _ActivityFormLoadState.failure);
      }
    }
  }

  bool _isCurrentLoad(int generation, ActivityDirectoryRepository repository, String? activityId) =>
      mounted &&
      generation == _loadGeneration &&
      identical(repository, widget.repository) &&
      activityId == widget.activityId;

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
    if (await _confirmExit() && mounted) widget.onDestinationSelected?.call(destination);
  }

  Future<void> _saveDraft() async {
    final controller = _controller;
    if (!mounted || controller == null || controller.isSubmitting) return;
    if (!controller.validateDraft()) return;
    if (controller.selectedLocationId != null) {
      setState(() => _failedCommand = _ActivityFormCommand.saveDraft);
      return;
    }
    final attempt = _attemptFor(controller, _ActivityFormCommand.saveDraft);
    if (attempt == null) {
      setState(() => _failedCommand = _ActivityFormCommand.saveDraft);
      return;
    }
    final generation = ++_commandGeneration;
    setState(() => _failedCommand = null);
    controller.setSubmitting(true);
    try {
      await widget.onSaveDraft(attempt.draft);
      if (_isCurrentCommand(generation, controller)) {
        _pendingAttempt = null;
        controller.markSubmitted();
      }
    } on Exception {
      if (_isCurrentCommand(generation, controller)) {
        setState(() => _failedCommand = _ActivityFormCommand.saveDraft);
      }
    } finally {
      if (_isCurrentCommand(generation, controller)) controller.setSubmitting(false);
    }
  }

  Future<void> _submit() async {
    final controller = _controller;
    if (!mounted || controller == null || controller.isSubmitting) return;
    if (!controller.validateCompletion()) return;
    if (controller.selectedLocationId != null ||
        controller.cataloguedLocationSelection != null ||
        controller.locationReservation != null) {
      setState(() => _failedCommand = _ActivityFormCommand.submit);
      return;
    }
    final attempt = _attemptFor(controller, _ActivityFormCommand.submit);
    if (attempt == null) {
      setState(() => _failedCommand = _ActivityFormCommand.submit);
      return;
    }
    final generation = ++_commandGeneration;
    setState(() => _failedCommand = null);
    controller.setSubmitting(true);
    try {
      await widget.onSubmit(attempt.draft);
      if (_isCurrentCommand(generation, controller)) {
        _pendingAttempt = null;
        controller.markSubmitted();
      }
    } on Exception {
      if (_isCurrentCommand(generation, controller)) {
        setState(() => _failedCommand = _ActivityFormCommand.submit);
      }
    } finally {
      if (_isCurrentCommand(generation, controller)) controller.setSubmitting(false);
    }
  }

  bool _isCurrentCommand(int generation, ActivityFormController controller) =>
      mounted && generation == _commandGeneration && identical(controller, _controller);

  _ActivityFormAttempt? _attemptFor(
    ActivityFormController controller,
    _ActivityFormCommand command,
  ) {
    final signature = controller.commandSignature;
    final pending = _pendingAttempt;
    if (pending != null) {
      return pending.command == command && pending.signature == signature ? pending : null;
    }
    final requestId = _newActivityRequestId();
    return _pendingAttempt = _ActivityFormAttempt(
      command: command,
      signature: signature,
      draft: controller.toDraft(requestId: requestId, commandSignature: signature),
    );
  }

  Future<void> _retryCatalogOptions() async {
    try {
      await _controller!.retryCatalogOptions();
    } on ActivityDirectoryUnauthorizedException {
      if (mounted) setState(() => _state = _ActivityFormLoadState.unauthorized);
    }
  }

  void _handleFooterHeightChanged(double height) {
    if ((_footerHeight - height).abs() < .5) return;
    setState(() => _footerHeight = height);
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    activityController: _activityController,
    title: _isEditing ? 'Editar atividade' : 'Criar atividade',
    subtitle: _isEditing
        ? 'Revise identidade, vínculos e profissionais desta atividade.'
        : 'Configure a atividade e seus vínculos institucionais.',
    currentDestination: 'activities',
    // Sem balao de chat em telas de criar e editar: decisao do Owner de
    // 10/09/2026. Essas telas pedem foco na tarefa em andamento.
    showChatLauncher: false,
    // Sempre entregar o handler ao shell, como Instituicoes e Turmas ja fazem.
    // _selectDestination e inofensivo quando widget.onDestinationSelected e nulo,
    // e a navegacao do menu nao deve depender de o chamador ter passado callback.
    onDestinationSelected: _selectDestination,
    onBugReportSubmitted: widget.onBugReportSubmitted,
    child: _body(MediaQuery.sizeOf(context).width),
  );

  Widget _body(double viewportWidth) => switch (_state) {
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
      viewportWidth: viewportWidth,
      onFooterHeightChanged: _handleFooterHeightChanged,
      controller: _controller!,
      onCancel: _requestCancel,
      onSaveDraft: _saveDraft,
      onSubmit: _submit,
      onCreateLocation: widget.onCreateLocation,
      locationSelectionBuilder: widget.locationSelectionBuilder,
      onRetryCatalogOptions: _retryCatalogOptions,
      imagePicker: widget.imagePicker ?? pickInstitutionLogo,
      aboutRepository: widget.aboutRepository,
      activityId: widget.activityId,
      failedCommand: _failedCommand,
      onRetryCommand: _failedCommand == _ActivityFormCommand.saveDraft ? _saveDraft : _submit,
    ),
  };
}

ActivityFormOptions _formOptionsFromTemplates(ActivityTemplateOptions options) =>
    ActivityFormOptions(
      institutions: options.institutions,
      taxonomy: options.taxonomy,
      templates: options.templates,
    );

String _newActivityRequestId() {
  final random = math.Random.secure();
  final values = List<int>.generate(16, (_) => random.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  final hex = values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return [
    hex.substring(0, 8),
    hex.substring(8, 12),
    hex.substring(12, 16),
    hex.substring(16, 20),
    hex.substring(20),
  ].join('-');
}

final class _ActivityFormAttempt {
  const _ActivityFormAttempt({required this.command, required this.signature, required this.draft});

  final _ActivityFormCommand command;
  final String signature;
  final ActivityFormDraft draft;
}

final class _ActivityFormBody extends StatelessWidget {
  const _ActivityFormBody({
    required this.controller,
    required this.viewportWidth,
    required this.onFooterHeightChanged,
    required this.onCancel,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onCreateLocation,
    this.locationSelectionBuilder,
    required this.onRetryCatalogOptions,
    required this.imagePicker,
    required this.aboutRepository,
    required this.activityId,
    required this.failedCommand,
    required this.onRetryCommand,
  });

  final ActivityFormController controller;
  final double viewportWidth;
  final ValueChanged<double> onFooterHeightChanged;
  final VoidCallback onCancel;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;
  final ActivityLocationCreator onCreateLocation;
  final ActivityLocationSelectionBuilder? locationSelectionBuilder;
  final Future<void> Function() onRetryCatalogOptions;
  final InstitutionLogoPicker imagePicker;
  final ActivityProfileAboutRepository aboutRepository;
  final String? activityId;
  final _ActivityFormCommand? failedCommand;
  final VoidCallback onRetryCommand;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => PopScope<void>(
      canPop: !controller.isDirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onCancel();
      },
      child: Builder(
        builder: (context) {
          final navigation = SuperadminFormStepNavigation(
            steps: [
              for (final step in ActivityFormStep.values)
                SuperadminFormStep(
                  label: switch (step) {
                    ActivityFormStep.identity => 'Identidade',
                    ActivityFormStep.structure => 'Estrutura e locais',
                    ActivityFormStep.pedagogical => 'Configuração pedagógica',
                    ActivityFormStep.links => 'Vínculos',
                    ActivityFormStep.about => 'Sobre do perfil',
                    ActivityFormStep.professionals => 'Profissionais e revisão',
                  },
                  status: step == controller.currentStep
                      ? SuperadminFormStepStatus.current
                      : step.index < controller.currentStep.index
                      ? SuperadminFormStepStatus.complete
                      : SuperadminFormStepStatus.incomplete,
                ),
            ],
            currentIndex: controller.currentStep.index,
            onStepSelected: controller.goToStep,
          );
          return SuperadminFormFrame(
            viewportWidth: viewportWidth,
            navigation: ExcludeFocus(
              excluding: controller.isSubmitting,
              child: AbsorbPointer(absorbing: controller.isSubmitting, child: navigation),
            ),
            scrollKey: const Key('activity-form-scroll'),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (failedCommand case final command?) ...[
                  CoeloStatePanel(
                    key: const Key('activity-form-command-error'),
                    title: command == _ActivityFormCommand.saveDraft
                        ? 'Não foi possível salvar o rascunho.'
                        : 'Não foi possível salvar a atividade.',
                    // Honesto: com avaliacao habilitada o salvar agregado nao
                    // existe (save_v2 nao carrega a configuracao avaliativa);
                    // a configuracao vive na tela propria da atividade.
                    message: controller.pedagogicalConfiguration.enabled
                        ? 'A avaliação é configurada na tela "Configuração avaliativa" da atividade. '
                              'Desative "Habilitar avaliação" para salvar o rascunho e configure a '
                              'avaliação depois.'
                        : 'Confira a conexão e tente novamente sem perder as alterações.',
                    icon: controller.pedagogicalConfiguration.enabled
                        ? Icons.info_outline_rounded
                        : Icons.cloud_off_outlined,
                    actionLabel: 'Tentar novamente',
                    onAction: onRetryCommand,
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                ],
                if (controller.isSubmitting)
                  Semantics(
                    liveRegion: true,
                    child: const Padding(
                      padding: EdgeInsets.only(bottom: CoeloSpacing.space3),
                      child: Text('Salvando alterações…'),
                    ),
                  ),
                ExcludeFocus(
                  excluding: controller.isSubmitting,
                  child: AbsorbPointer(
                    absorbing: controller.isSubmitting,
                    child: ActivityFormSection(
                      controller: controller,
                      onCreateLocation: onCreateLocation,
                      locationSelectionBuilder: locationSelectionBuilder,
                      onRetryCatalogOptions: onRetryCatalogOptions,
                      imagePicker: imagePicker,
                      aboutRepository: aboutRepository,
                      activityId: activityId,
                    ),
                  ),
                ),
              ],
            ),
            footer: _ActivityFormFooter(
              controller: controller,
              onCancel: onCancel,
              onSaveDraft: onSaveDraft,
              onSubmit: onSubmit,
              onHeightChanged: onFooterHeightChanged,
            ),
          );
        },
      ),
    ),
  );
}

final class _ActivityFormFooter extends StatelessWidget {
  const _ActivityFormFooter({
    required this.controller,
    required this.onCancel,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onHeightChanged,
  });

  final ActivityFormController controller;
  final VoidCallback onCancel;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;
  final ValueChanged<double> onHeightChanged;

  @override
  Widget build(BuildContext context) {
    const actionStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, CoeloSize.touchMin)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: CoeloSpacing.space3)),
    );
    final cancel = TextButton(
      key: const Key('activity-form-cancel'),
      onPressed: controller.isSubmitting ? null : onCancel,
      child: const Text('Cancelar'),
    );
    final previous = OutlinedButton(
      key: const Key('activity-form-previous'),
      style: actionStyle,
      onPressed: controller.isSubmitting ? null : controller.previousStep,
      child: const Text('Anterior'),
    );
    final draft = OutlinedButton(
      key: const Key('activity-form-save-draft'),
      style: actionStyle,
      onPressed: controller.isSubmitting || !controller.canSaveDraft ? null : onSaveDraft,
      child: const Text('Salvar rascunho'),
    );
    final primary = FilledButton(
      key: Key(controller.isLastStep ? 'activity-form-submit' : 'activity-form-continue'),
      style: actionStyle,
      onPressed: controller.isSubmitting
          ? null
          : controller.isLastStep
          ? onSubmit
          : controller.continueFromCurrentStep,
      child: controller.isSubmitting
          ? const SizedBox.square(
              dimension: CoeloSize.iconSm,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              controller.isLastStep
                  ? controller.isEditing
                        ? 'Salvar alterações'
                        : 'Criar atividade'
                  : 'Continuar',
            ),
    );
    return SuperadminFormActionFooter(
      onHeightChanged: onHeightChanged,
      surfaceKey: const Key('activity-form-footer-surface'),
      tertiaryAction: cancel,
      continuationActions: [
        if (!controller.isFirstStep) previous,
        if (controller.canSaveDraft) draft,
        primary,
      ],
    );
  }
}
