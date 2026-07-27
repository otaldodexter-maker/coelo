import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
import '../../data/fake_institution_directory_repository.dart';
import '../view_models/institution_form_controller.dart';
import '../widgets/institution_form_dialogs.dart';
import '../widgets/institution_form_navigation.dart';
import '../widgets/institution_form_sections.dart';

enum InstitutionFormSaveResult { created, updated }

final class InstitutionFormPage extends StatefulWidget {
  const InstitutionFormPage({
    required this.repository,
    required this.logout,
    required this.onCancel,
    required this.onSaved,
    this.institutionId,
    this.onDestinationSelected,
    super.key,
  });

  final FakeInstitutionDirectoryRepository repository;
  final String? institutionId;
  final LogoutAction logout;
  final VoidCallback onCancel;
  final ValueChanged<InstitutionFormSaveResult> onSaved;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<InstitutionFormPage> createState() => _InstitutionFormPageState();
}

final class _InstitutionFormPageState extends State<InstitutionFormPage> {
  InstitutionFormController? _controller;
  bool _missingInstitution = false;

  @override
  void initState() {
    super.initState();
    final id = widget.institutionId;
    final record = id == null ? null : widget.repository.findById(id);
    _missingInstitution = id != null && record == null;
    if (!_missingInstitution) {
      _controller = InstitutionFormController(record: record);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
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
    if (!controller.validateAll()) {
      return;
    }
    controller.setSaving(true);
    await Future<void>.delayed(
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : CoeloMotion.short,
    );
    if (!mounted) {
      return;
    }
    final creating = widget.institutionId == null;
    final id =
        widget.institutionId ??
        widget.repository.createId(controller.text(InstitutionFormField.slug));
    await widget.repository.upsert(controller.toRecord(id: id));
    if (!mounted) {
      return;
    }
    controller.setSaving(false);
    widget.onSaved(
      creating ? InstitutionFormSaveResult.created : InstitutionFormSaveResult.updated,
    );
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
    return LayoutBuilder(
      builder: (context, constraints) => SuperadminShell(
        logout: widget.logout,
        title: title,
        subtitle: widget.institutionId == null
            ? 'Adicione uma nova instituição ao Coelo.'
            : 'Atualize os dados da instituição selecionada.',
        onDestinationSelected: _selectDestination,
        child: _missingInstitution
            ? CoeloStatePanel(
                key: const Key('institution-form-not-found'),
                title: 'Instituição não encontrada',
                message: 'O registro solicitado não existe nesta sessão local.',
                icon: Icons.search_off_rounded,
                actionLabel: 'Voltar às instituições',
                onAction: widget.onCancel,
              )
            : _FormBody(
                controller: _controller!,
                onCancel: _requestExit,
                onSave: _save,
                desktopNavigation: constraints.maxWidth >= CoeloBreakpoints.large.minWidth,
              ),
      ),
    );
  }
}

final class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.controller,
    required this.onCancel,
    required this.onSave,
    required this.desktopNavigation,
  });

  final InstitutionFormController controller;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final bool desktopNavigation;

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = desktopNavigation;
              final navigation = InstitutionFormNavigation(controller: controller);
              final content = Expanded(
                child: Column(
                  children: [
                    if (!desktop) ...[navigation, const SizedBox(height: CoeloSpacing.space4)],
                    Expanded(
                      child: SingleChildScrollView(
                        key: const Key('institution-form-scroll'),
                        padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 880),
                            child: AnimatedSwitcher(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : CoeloMotion.short,
                              transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.025, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                              child: KeyedSubtree(
                                key: ValueKey(controller.currentStep),
                                child: InstitutionFormSection(controller: controller),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _FormFooter(controller: controller, onCancel: onCancel, onSave: onSave),
                  ],
                ),
              );
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  desktop ? CoeloSpacing.space5 : CoeloSpacing.space3,
                  CoeloSpacing.space4,
                  desktop ? CoeloSpacing.space5 : CoeloSpacing.space3,
                  CoeloSpacing.space3,
                ),
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
        );
      },
    );
  }
}

final class _FormFooter extends StatelessWidget {
  const _FormFooter({required this.controller, required this.onCancel, required this.onSave});
  final InstitutionFormController controller;
  final VoidCallback onCancel;
  final VoidCallback onSave;

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
    final primaryButton = FilledButton(
      key: last ? const Key('institution-form-save') : const Key('institution-form-continue'),
      onPressed: controller.isSaving
          ? null
          : last
          ? onSave
          : controller.continueFromCurrentStep,
      child: controller.isSaving
          ? const SizedBox.square(
              dimension: CoeloSize.iconSm,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              last
                  ? controller.isEditing
                        ? 'Salvar alterações'
                        : 'Criar instituição'
                  : 'Continuar',
            ),
    );
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  primaryButton,
                  const SizedBox(height: CoeloSpacing.space2),
                  Row(
                    children: [
                      cancelButton,
                      const Spacer(),
                      if (controller.currentStep.index > 0) previousButton,
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                cancelButton,
                const Spacer(),
                if (controller.currentStep.index > 0) previousButton,
                const SizedBox(width: CoeloSpacing.space2),
                primaryButton,
              ],
            );
          },
        ),
      ),
    );
  }
}
