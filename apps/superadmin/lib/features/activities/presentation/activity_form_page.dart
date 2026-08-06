import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../../auth/domain/logout_action.dart';
import '../../institutions/presentation/widgets/institution_logo_picker_stub.dart'
    if (dart.library.html) '../../institutions/presentation/widgets/institution_logo_picker_web.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/activity_directory.dart';
import 'activity_form_controller.dart';
import 'activity_form_draft.dart';
import 'activity_form_sections.dart';

typedef ActivityFormSubmit = Future<void> Function(ActivityFormDraft draft);
typedef ActivityLocationCreator =
    Future<ActivityFormLocationOption> Function(ActivityLocationDraft draft);

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
    this.initialDraft,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    this.imagePicker,
    super.key,
  });

  final String? activityId;
  final String? initialInstitutionId;
  final String? initialUnitId;
  final ActivityFormDraft? initialDraft;
  final ActivityDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback onCancel;
  final ActivityFormSubmit onSaveDraft;
  final ActivityFormSubmit onSubmit;
  final ActivityLocationCreator onCreateLocation;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final InstitutionLogoPicker? imagePicker;

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
            ? ActivityFormController.edit(options, detail!, initialDraft: widget.initialDraft)
            : ActivityFormController.create(
                options,
                initialInstitutionId: widget.initialInstitutionId,
                initialUnitId: widget.initialUnitId,
              );
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

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    activityController: _activityController,
    title: _isEditing ? 'Editar atividade' : 'Criar atividade',
    subtitle: _isEditing
        ? 'Revise identidade, vínculos e profissionais desta atividade.'
        : 'Configure a atividade e seus vínculos institucionais.',
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
      onSaveDraft: _saveDraft,
      onSubmit: _submit,
      onCreateLocation: widget.onCreateLocation,
      imagePicker: widget.imagePicker ?? pickInstitutionLogo,
    ),
  };
}

final class _ActivityFormBody extends StatelessWidget {
  const _ActivityFormBody({
    required this.controller,
    required this.onCancel,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onCreateLocation,
    required this.imagePicker,
  });

  final ActivityFormController controller;
  final VoidCallback onCancel;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;
  final ActivityLocationCreator onCreateLocation;
  final InstitutionLogoPicker imagePicker;

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
          final desktop = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth;
          final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
              ? CoeloSpacing.space10
              : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space6
              : CoeloSpacing.space4;
          final navigation = SuperadminFormStepNavigation(
            steps: [
              for (final step in ActivityFormStep.values)
                SuperadminFormStep(
                  label: switch (step) {
                    ActivityFormStep.identity => 'Identidade',
                    ActivityFormStep.structure => 'Estrutura e locais',
                    ActivityFormStep.links => 'Vínculos',
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
          final content = Expanded(
            child: Column(
              children: [
                if (!desktop) ...[navigation, const SizedBox(height: CoeloSpacing.space4)],
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('activity-form-scroll'),
                    padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 880),
                        child: ActivityFormSection(
                          controller: controller,
                          onCreateLocation: onCreateLocation,
                          imagePicker: imagePicker,
                        ),
                      ),
                    ),
                  ),
                ),
                _ActivityFormFooter(
                  controller: controller,
                  onCancel: onCancel,
                  onSaveDraft: onSaveDraft,
                  onSubmit: onSubmit,
                ),
              ],
            ),
          );
          return Padding(
            padding: EdgeInsets.fromLTRB(inset, inset, inset, CoeloSpacing.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desktop) ...[navigation, const SizedBox(width: CoeloSpacing.space6)],
                content,
              ],
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
  });

  final ActivityFormController controller;
  final VoidCallback onCancel;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;

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
