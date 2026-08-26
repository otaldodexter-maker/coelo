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
import '../domain/activity_profile_about_repository.dart';
import 'activity_form_controller.dart';
import 'activity_form_draft.dart';
import 'activity_form_sections.dart';

typedef ActivityFormSubmit = Future<void> Function(ActivityFormDraft draft);
typedef ActivityLocationCreator =
    Future<List<ActivityFormLocationOption>> Function(ActivityLocationDraft draft);

enum _ActivityFormLoadState { loading, ready, notFound, failure, unauthorized }

final class ActivityFormPage extends StatefulWidget {
  const ActivityFormPage({
    required this.repository,
    required this.logout,
    required this.onCancel,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onCreateLocation,
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
  final LogoutAction logout;
  final VoidCallback onCancel;
  final ActivityFormSubmit onSaveDraft;
  final ActivityFormSubmit onSubmit;
  final ActivityLocationCreator onCreateLocation;
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
      final detail = _isEditing ? await widget.repository.fetchById(widget.activityId!) : null;
      if (_isEditing && detail == null) {
        if (mounted) setState(() => _state = _ActivityFormLoadState.notFound);
        return;
      }
      ActivityFormOptions options;
      String? initialCatalogError;
      if (_isEditing || widget.initialInstitutionId != null) {
        options = await widget.repository.fetchFormOptions(
          institutionId: detail?.item.institutionId ?? widget.initialInstitutionId!,
        );
      } else {
        try {
          options = _formOptionsFromTemplates(await widget.repository.fetchTemplateOptions());
        } on ActivityDirectoryUnauthorizedException {
          rethrow;
        } on Exception {
          ActivityFilterOptions filters;
          try {
            filters = await widget.repository.fetchFilterOptions();
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
      if (!mounted) return;
      _controller?.dispose();
      final nextController = _isEditing
          ? ActivityFormController.edit(
              options,
              detail!,
              initialDraft: widget.initialDraft,
              professionalSearcher: (institutionId, query) =>
                  widget.repository.searchProfessionals(institutionId: institutionId, query: query),
            )
          : ActivityFormController.create(
              options,
              initialInstitutionId: widget.initialInstitutionId,
              initialUnitId: widget.initialUnitId,
              initialTemplateId: widget.initialTemplateId,
              loadScopedOptions: (institutionId) =>
                  widget.repository.fetchFormOptions(institutionId: institutionId),
              loadTemplateOptions: (institutionId) =>
                  widget.repository.fetchTemplateOptions(institutionId: institutionId),
              initialCatalogError: initialCatalogError,
              professionalSearcher: (institutionId, query) =>
                  widget.repository.searchProfessionals(institutionId: institutionId, query: query),
            );
      if (widget.initialStep case final step?) {
        nextController.goToStep(step.index);
      }
      if (!mounted) return;
      setState(() {
        _controller = nextController;
        _state = _ActivityFormLoadState.ready;
      });
    } on ActivityDirectoryUnauthorizedException {
      if (mounted) setState(() => _state = _ActivityFormLoadState.unauthorized);
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
    if (await _confirmExit() && mounted) widget.onDestinationSelected?.call(destination);
  }

  Future<void> _saveDraft() async {
    final controller = _controller!;
    if (!controller.validateDraft()) return;
    controller.setSubmitting(true);
    try {
      await widget.onSaveDraft(controller.toDraft());
      if (mounted) controller.markSubmitted();
    } finally {
      if (mounted) controller.setSubmitting(false);
    }
  }

  Future<void> _submit() async {
    final controller = _controller!;
    if (!controller.validateCompletion()) return;
    controller.setSubmitting(true);
    try {
      await widget.onSubmit(controller.toDraft());
      if (mounted) controller.markSubmitted();
    } finally {
      if (mounted) controller.setSubmitting(false);
    }
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
    chatLauncherBottomInset: _footerHeight == 0 ? 0 : _footerHeight + CoeloSpacing.space4,
    onDestinationSelected: widget.onDestinationSelected == null ? null : _selectDestination,
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
      onRetryCatalogOptions: _retryCatalogOptions,
      imagePicker: widget.imagePicker ?? pickInstitutionLogo,
      aboutRepository: widget.aboutRepository,
      activityId: widget.activityId,
    ),
  };
}

ActivityFormOptions _formOptionsFromTemplates(ActivityTemplateOptions options) =>
    ActivityFormOptions(
      institutions: options.institutions,
      taxonomy: options.taxonomy,
      templates: options.templates,
    );

final class _ActivityFormBody extends StatelessWidget {
  const _ActivityFormBody({
    required this.controller,
    required this.viewportWidth,
    required this.onFooterHeightChanged,
    required this.onCancel,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onCreateLocation,
    required this.onRetryCatalogOptions,
    required this.imagePicker,
    required this.aboutRepository,
    required this.activityId,
  });

  final ActivityFormController controller;
  final double viewportWidth;
  final ValueChanged<double> onFooterHeightChanged;
  final VoidCallback onCancel;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;
  final ActivityLocationCreator onCreateLocation;
  final Future<void> Function() onRetryCatalogOptions;
  final InstitutionLogoPicker imagePicker;
  final ActivityProfileAboutRepository aboutRepository;
  final String? activityId;

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
            navigation: navigation,
            scrollKey: const Key('activity-form-scroll'),
            body: ActivityFormSection(
              controller: controller,
              onCreateLocation: onCreateLocation,
              onRetryCatalogOptions: onRetryCatalogOptions,
              imagePicker: imagePicker,
              aboutRepository: aboutRepository,
              activityId: activityId,
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
