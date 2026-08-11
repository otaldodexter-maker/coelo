import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_shell.dart';
import '../../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../auth/domain/logout_action.dart';
import '../../data/institution_location_service.dart';
import '../../domain/institution_directory_repository.dart';
import '../view_models/institution_form_controller.dart';
import '../widgets/institution_form_dialogs.dart';
import '../widgets/institution_form_navigation.dart';
import '../widgets/institution_form_sections.dart';
import '../widgets/institution_logo_picker.dart';

enum InstitutionFormSaveResult { created, updated }

final class InstitutionFormPage extends StatefulWidget {
  const InstitutionFormPage({
    required this.repository,
    required this.logout,
    required this.onCancel,
    required this.onSaved,
    this.institutionId,
    this.locationService,
    this.onDestinationSelected,
    this.imagePicker,
    super.key,
  });

  final InstitutionDirectoryRepository repository;
  final String? institutionId;
  final InstitutionLocationService? locationService;
  final LogoutAction logout;
  final VoidCallback onCancel;
  final ValueChanged<InstitutionFormSaveResult> onSaved;
  final ValueChanged<String>? onDestinationSelected;
  final InstitutionLogoPicker? imagePicker;

  @override
  State<InstitutionFormPage> createState() => _InstitutionFormPageState();
}

final class _InstitutionFormPageState extends State<InstitutionFormPage> {
  InstitutionFormController? _controller;
  late final InstitutionLocationService _locationService;
  _InstitutionFormLoadState _loadState = _InstitutionFormLoadState.loading;
  var _loadSequence = 0;
  double _footerHeight = 0;

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? InstitutionLocationService();
    if (widget.institutionId == null) {
      _controller = InstitutionFormController();
      _loadState = _InstitutionFormLoadState.ready;
    } else {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final id = widget.institutionId;
    if (id == null) return;
    final sequence = ++_loadSequence;
    _controller?.dispose();
    _controller = null;
    if (mounted) {
      setState(() => _loadState = _InstitutionFormLoadState.loading);
    }
    try {
      final record = await widget.repository.fetchById(id);
      if (!mounted || sequence != _loadSequence) return;
      setState(() {
        _controller = InstitutionFormController(record: record);
        _loadState = _InstitutionFormLoadState.ready;
      });
    } on InstitutionDirectoryUnauthorizedException {
      _completeLoad(sequence, _InstitutionFormLoadState.unauthorized);
    } on InstitutionDirectoryNotFoundException {
      _completeLoad(sequence, _InstitutionFormLoadState.notFound);
    } on InstitutionDirectoryUnavailableException {
      _completeLoad(sequence, _InstitutionFormLoadState.unavailable);
    } catch (_) {
      _completeLoad(sequence, _InstitutionFormLoadState.unexpected);
    }
  }

  void _completeLoad(int sequence, _InstitutionFormLoadState state) {
    if (!mounted || sequence != _loadSequence) return;
    setState(() => _loadState = state);
  }

  @override
  void dispose() {
    _loadSequence++;
    _controller?.dispose();
    if (widget.locationService == null) {
      _locationService.close();
    }
    super.dispose();
  }

  Future<void> _requestExit() async {
    final controller = _controller;
    if (controller == null || !controller.isDirty || await showInstitutionExitDialog(context)) {
      widget.onCancel();
    }
  }

  Future<void> _save() async {
    final controller = _controller!;
    final creating = widget.institutionId == null;
    if (!(creating ? controller.validateAll() : controller.validateEditSave())) {
      return;
    }
    final saveContractError = controller.saveContractError;
    if (saveContractError != null) {
      _showSaveFailure(saveContractError);
      return;
    }
    controller.setSaving(true);
    await Future<void>.delayed(
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : CoeloMotion.short,
    );
    if (!mounted) return;
    try {
      final draft = controller.toRecord(id: widget.institutionId ?? '');
      final saved = creating
          ? await widget.repository.create(draft)
          : await widget.repository.update(draft, expectedVersion: draft.version);
      if (!mounted) return;
      controller.setSaving(false);
      if (!creating) {
        controller.markSaved(version: saved.version);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Alterações salvas.')));
        return;
      }
      widget.onSaved(InstitutionFormSaveResult.created);
    } on InstitutionDirectoryUnauthorizedException {
      _showSaveFailure('Você não tem permissão para salvar esta instituição.');
    } on InstitutionDirectoryNotFoundException {
      _showSaveFailure('A instituição não existe mais. Volte à lista e tente novamente.');
    } on InstitutionDirectoryConflictException {
      _showSaveFailure(
        'Esta instituição foi alterada por outra pessoa. Recarregue antes de salvar.',
      );
    } on InstitutionDirectoryValidationException catch (error) {
      _showSaveFailure(error.message);
    } on InstitutionDirectoryUnsupportedRelationException {
      _showSaveFailure('Representantes e administradores ainda não podem ser salvos neste fluxo.');
    } on InstitutionDirectoryUnavailableException {
      _showSaveFailure('Não foi possível conectar ao serviço. Tente novamente.');
    } catch (_) {
      _showSaveFailure('Não foi possível salvar a instituição. Tente novamente.');
    }
  }

  void _showSaveFailure(String message) {
    if (!mounted) return;
    _controller?.setSaving(false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectDestination(String destination) async {
    final controller = _controller;
    if (controller != null && controller.isDirty && !await showInstitutionExitDialog(context)) {
      return;
    }
    widget.onDestinationSelected?.call(destination);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.institutionId == null ? 'Criar instituição' : 'Editar instituição';
    final viewportWidth = MediaQuery.sizeOf(context).width;
    return SuperadminShell(
      logout: widget.logout,
      title: title,
      subtitle: widget.institutionId == null
          ? 'Adicione uma nova instituição ao Coelo.'
          : 'Atualize os dados da instituição selecionada.',
      showChatLauncher: _loadState != _InstitutionFormLoadState.ready || _footerHeight > 0,
      chatLauncherBottomInset: _footerHeight == 0 ? 0 : _footerHeight + CoeloSpacing.space4,
      onDestinationSelected: _selectDestination,
      child: switch (_loadState) {
        _InstitutionFormLoadState.loading => const Center(
          key: Key('institution-form-loading'),
          child: CircularProgressIndicator(),
        ),
        _InstitutionFormLoadState.notFound => CoeloStatePanel(
          key: const Key('institution-form-not-found'),
          title: 'Instituição não encontrada',
          message: 'O registro solicitado não foi encontrado.',
          icon: Icons.search_off_rounded,
          actionLabel: 'Voltar às instituições',
          onAction: widget.onCancel,
        ),
        _InstitutionFormLoadState.unauthorized => CoeloStatePanel(
          key: const Key('institution-form-unauthorized'),
          title: 'Acesso não autorizado',
          message: 'Você não tem permissão para acessar esta instituição.',
          icon: Icons.lock_outline_rounded,
          actionLabel: 'Voltar às instituições',
          onAction: widget.onCancel,
        ),
        _InstitutionFormLoadState.unavailable => CoeloStatePanel(
          key: const Key('institution-form-unavailable'),
          title: 'Não foi possível carregar',
          message: 'Verifique sua conexão e tente novamente.',
          icon: Icons.cloud_off_outlined,
          actionLabel: 'Tentar novamente',
          onAction: _load,
        ),
        _InstitutionFormLoadState.unexpected => CoeloStatePanel(
          key: const Key('institution-form-error'),
          title: 'Não foi possível carregar',
          message: 'Ocorreu uma falha inesperada. Tente novamente.',
          icon: Icons.error_outline_rounded,
          actionLabel: 'Tentar novamente',
          onAction: _load,
        ),
        _InstitutionFormLoadState.ready => _FormBody(
          controller: _controller!,
          onCancel: _requestExit,
          onSave: _save,
          locationService: _locationService,
          imagePicker: widget.imagePicker ?? pickInstitutionLogo,
          onFooterHeightChanged: (height) {
            if ((_footerHeight - height).abs() < .5 || !mounted) return;
            setState(() => _footerHeight = height);
          },
          viewportWidth: viewportWidth,
        ),
      },
    );
  }
}

enum _InstitutionFormLoadState { loading, ready, notFound, unauthorized, unavailable, unexpected }

final class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.controller,
    required this.onCancel,
    required this.onSave,
    required this.locationService,
    required this.imagePicker,
    required this.onFooterHeightChanged,
    required this.viewportWidth,
  });

  final InstitutionFormController controller;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final InstitutionLocationService locationService;
  final InstitutionLogoPicker imagePicker;
  final ValueChanged<double> onFooterHeightChanged;
  final double viewportWidth;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return PopScope<void>(
          canPop: !controller.isDirty,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              onCancel();
            }
          },
          child: SuperadminFormFrame(
            viewportWidth: viewportWidth,
            navigation: InstitutionFormNavigation(controller: controller),
            scrollKey: const Key('institution-form-scroll'),
            body: InstitutionFormSection(
              controller: controller,
              locationService: locationService,
              imagePicker: imagePicker,
            ),
            footer: _FormFooter(
              controller: controller,
              onCancel: onCancel,
              onSave: onSave,
              onHeightChanged: onFooterHeightChanged,
            ),
          ),
        );
      },
    );
  }
}

final class _FormFooter extends StatelessWidget {
  const _FormFooter({
    required this.controller,
    required this.onCancel,
    required this.onSave,
    required this.onHeightChanged,
  });
  final InstitutionFormController controller;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final ValueChanged<double> onHeightChanged;

  @override
  Widget build(BuildContext context) {
    final last = controller.currentStep == InstitutionFormStep.review;
    final cancelButton = TextButton(
      key: const Key('institution-form-cancel'),
      onPressed: controller.isSaving ? null : onCancel,
      child: const Text('Cancelar'),
    );
    final previousButton = OutlinedButton(
      key: const Key('institution-form-previous'),
      onPressed: controller.isSaving ? null : controller.previousStep,
      child: const Text('Anterior'),
    );
    final primaryLabel = last
        ? controller.isEditing
              ? 'Salvar alterações'
              : 'Criar instituição'
        : 'Continuar';
    final primaryKey = last
        ? const Key('institution-form-save')
        : const Key('institution-form-continue');
    final primaryAction = controller.isSaving
        ? null
        : last
        ? onSave
        : controller.continueFromCurrentStep;
    final primaryChild = controller.isSaving
        ? const SizedBox.square(
            dimension: CoeloSize.iconSm,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(primaryLabel);
    final Widget primaryButton = controller.isEditing && !last
        ? OutlinedButton(key: primaryKey, onPressed: primaryAction, child: primaryChild)
        : FilledButton(key: primaryKey, onPressed: primaryAction, child: primaryChild);
    final saveCurrentButton = FilledButton(
      key: const Key('institution-form-save-current'),
      onPressed: controller.isSaving ? null : onSave,
      child: controller.isSaving
          ? const SizedBox.square(
              dimension: CoeloSize.iconSm,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Salvar alterações'),
    );
    return SuperadminFormActionFooter(
      surfaceKey: const Key('institution-form-footer-surface'),
      onHeightChanged: onHeightChanged,
      tertiaryAction: cancelButton,
      continuationActions: [
        if (controller.currentStep.index > 0) previousButton,
        primaryButton,
        if (controller.isEditing && !last) saveCurrentButton,
      ],
    );
  }
}
