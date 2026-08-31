import 'dart:math';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

enum _LifecycleAction { edit, duplicate, copy, move, schedules, archive, delete }

final class FormsLifecycleActions extends StatefulWidget {
  const FormsLifecycleActions({
    required this.api,
    required this.formId,
    required this.formTitle,
    required this.managementVersion,
    required this.canManage,
    this.canTransferCrossInstitution = false,
    this.requestIdFactory,
    this.onCompleted,
    this.onEdit,
    this.onManageSchedules,
    super.key,
  });

  final FormsApi? api;
  final String formId;
  final String formTitle;
  final int managementVersion;
  final bool canManage;
  final bool canTransferCrossInstitution;
  final String Function()? requestIdFactory;
  final VoidCallback? onCompleted;
  final VoidCallback? onEdit;
  final VoidCallback? onManageSchedules;

  @override
  State<FormsLifecycleActions> createState() => _FormsLifecycleActionsState();
}

final class _FormsLifecycleActionsState extends State<FormsLifecycleActions> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final canMutate = widget.canManage && widget.api != null;
    if (!canMutate && widget.onManageSchedules == null) return const SizedBox.shrink();
    return CoeloAdminFlyout<_LifecycleAction>(
      alignmentOffset: const Offset(0, CoeloSpacing.space1),
      viewportGap: CoeloSpacing.space3,
      elevation: CoeloElevation.level0,
      alignPanelToViewportEnd: true,
      crossAxisUnconstrained: true,
      outlineOpacity: 0.38,
      items: [
        if (canMutate && widget.onEdit != null)
          const CoeloAdminFlyoutItem(
            value: _LifecycleAction.edit,
            label: 'Editar',
            icon: Icons.edit_outlined,
          ),
        if (canMutate)
          const CoeloAdminFlyoutItem(
            value: _LifecycleAction.duplicate,
            label: 'Duplicar',
            icon: Icons.content_copy_rounded,
          ),
        if (canMutate && widget.canTransferCrossInstitution) ...const [
          CoeloAdminFlyoutItem(
            value: _LifecycleAction.copy,
            label: 'Copiar para instituição',
            icon: Icons.copy_all_rounded,
          ),
          CoeloAdminFlyoutItem(
            value: _LifecycleAction.move,
            label: 'Mover para instituição',
            icon: Icons.drive_file_move_outline,
          ),
        ],
        if (widget.onManageSchedules != null)
          const CoeloAdminFlyoutItem(
            value: _LifecycleAction.schedules,
            label: 'Agendamentos',
            icon: Icons.event_repeat_outlined,
          ),
        if (canMutate) ...const [
          CoeloAdminFlyoutItem(
            value: _LifecycleAction.archive,
            label: 'Arquivar',
            icon: Icons.archive_outlined,
            startsGroup: true,
            tone: CoeloAdminFlyoutTone.negative,
          ),
          CoeloAdminFlyoutItem(
            value: _LifecycleAction.delete,
            label: 'Excluir',
            icon: Icons.delete_outline_rounded,
            tone: CoeloAdminFlyoutTone.negative,
          ),
        ],
      ],
      onSelected: _loading ? (_) {} : _select,
      builder: (context, controller) => IconButton(
        key: ValueKey('form-lifecycle-actions-${widget.formId}'),
        tooltip: 'Ações do formulário ${widget.formTitle}',
        onPressed: _loading ? null : controller.open,
        icon: _loading
            ? const SizedBox.square(
                dimension: CoeloSize.iconMd,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.more_vert_rounded),
      ),
    );
  }

  Future<void> _select(_LifecycleAction action) async {
    switch (action) {
      case _LifecycleAction.edit:
        widget.onEdit?.call();
      case _LifecycleAction.duplicate:
        if (await _confirm(
          title: 'Duplicar formulário?',
          message: 'Uma nova cópia em rascunho será criada sem respostas ou histórico.',
          confirmLabel: 'Duplicar',
        )) {
          await _run(
            () => widget.api!.duplicate(
              FormCommand(
                requestId: _requestId(),
                expectedVersion: widget.managementVersion,
                payload: FormIdPayload(widget.formId),
              ),
            ),
            'Formulário duplicado.',
          );
        }
      case _LifecycleAction.copy:
      case _LifecycleAction.move:
        final mode = action == _LifecycleAction.copy
            ? FormCopyOrMoveMode.copy
            : FormCopyOrMoveMode.move;
        final target = await showDialog<String>(
          context: context,
          barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
          builder: (_) => _TransferDialog(mode: mode, formTitle: widget.formTitle),
        );
        if (target == null || !mounted) return;
        await _run(
          () => widget.api!.copyOrMove(
            FormCommand(
              requestId: _requestId(),
              expectedVersion: widget.managementVersion,
              payload: FormCopyOrMovePayload(
                formId: widget.formId,
                targetInstitutionId: target,
                mode: mode,
              ),
            ),
          ),
          mode == FormCopyOrMoveMode.copy ? 'Formulário copiado.' : 'Formulário movido.',
        );
      case _LifecycleAction.schedules:
        widget.onManageSchedules?.call();
      case _LifecycleAction.archive:
      case _LifecycleAction.delete:
        final deleting = action == _LifecycleAction.delete;
        if (await _confirm(
          title: deleting ? 'Excluir formulário?' : 'Arquivar formulário?',
          message: deleting
              ? 'Somente um rascunho nunca publicado e sem uso será excluído. Nos demais casos, o backend preservará o histórico e arquivará o formulário.'
              : 'O formulário deixará de aparecer entre os itens ativos, preservando respostas e histórico.',
          confirmLabel: deleting ? 'Excluir' : 'Arquivar',
          negative: true,
        )) {
          await _run(
            () => widget.api!.archiveOrDelete(
              FormCommand(
                requestId: _requestId(),
                expectedVersion: widget.managementVersion,
                payload: FormArchiveOrDeletePayload(
                  formId: widget.formId,
                  action: deleting
                      ? FormArchiveOrDeleteAction.delete
                      : FormArchiveOrDeleteAction.archive,
                ),
              ),
            ),
            deleting ? 'Formulário excluído ou arquivado com segurança.' : 'Formulário arquivado.',
          );
        }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool negative = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
        builder: (dialogContext) => CoeloAdminDialogShell(
          title: title,
          closeTooltip: 'Fechar confirmação',
          body: Text(message),
          secondaryAction: OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          primaryAction: FilledButton(
            style: negative
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ),
      ) ??
      false;

  Future<void> _run(Future<Object?> Function() operation, String successMessage) async {
    setState(() => _loading = true);
    try {
      await operation();
      if (!mounted) return;
      _message(successMessage);
      widget.onCompleted?.call();
    } on FormApiException catch (error) {
      if (!mounted) return;
      _message(_failureMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _requestId() => widget.requestIdFactory?.call() ?? _secureUuid();
}

final class _TransferDialog extends StatefulWidget {
  const _TransferDialog({required this.mode, required this.formTitle});

  final FormCopyOrMoveMode mode;
  final String formTitle;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

final class _TransferDialogState extends State<_TransferDialog> {
  final _target = TextEditingController();

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moving = widget.mode == FormCopyOrMoveMode.move;
    final label = moving ? 'Mover' : 'Copiar';
    final valid = _uuidPattern.hasMatch(_target.text.trim());
    return CoeloAdminDialogShell(
      title: '$label formulário?',
      closeTooltip: 'Fechar transferência',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            moving
                ? 'O rascunho virgem será movido; formulários com uso serão copiados como rascunho no destino.'
                : 'Uma cópia em rascunho será criada no destino, sem respostas ou histórico.',
          ),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloFormTextField(
            fieldKey: const Key('form-lifecycle-target-institution'),
            controller: _target,
            labelText: 'ID da instituição de destino',
            hintText: '00000000-0000-0000-0000-000000000000',
            prefixIcon: Icons.apartment_rounded,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      secondaryAction: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      primaryAction: FilledButton(
        style: moving
            ? FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              )
            : null,
        onPressed: valid ? () => Navigator.of(context).pop(_target.text.trim()) : null,
        child: Text(label),
      ),
    );
  }
}

String _failureMessage(FormApiException error) => switch (error.kind) {
  FormApiFailureKind.conflict =>
    'O formulário foi alterado em outra sessão. Recarregue e tente novamente.',
  FormApiFailureKind.unauthorized => 'Você não possui permissão para esta ação.',
  FormApiFailureKind.validation => error.message,
  FormApiFailureKind.unavailable => 'O serviço está indisponível. Tente novamente.',
  FormApiFailureKind.unknown => 'Não foi possível concluir a ação. Tente novamente.',
};

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

String _secureUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
