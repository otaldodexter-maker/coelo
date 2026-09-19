import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../domain/institution_directory_item.dart';

enum InstitutionLifecycleAction { edit, activate, inactivate, delete }

/// Ações de ciclo de vida da instituição (spec 066): ⋯ no card e na tabela.
/// Só oferece o que o status atual permite; a decisão final é do servidor.
final class InstitutionLifecycleMenu extends StatelessWidget {
  const InstitutionLifecycleMenu({
    super.key,
    required this.item,
    required this.onSelected,
    this.canEdit = false,
  });

  final InstitutionDirectoryItem item;
  final bool canEdit;
  final ValueChanged<InstitutionLifecycleAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final archived = item.status == InstitutionStatus.archived;
    return CoeloAdminFlyout<InstitutionLifecycleAction>(
      items: [
        if (canEdit)
          const CoeloAdminFlyoutItem(
            value: InstitutionLifecycleAction.edit,
            icon: Icons.edit_outlined,
            label: 'Editar',
          ),
        if (!archived && item.status != InstitutionStatus.active)
          const CoeloAdminFlyoutItem(
            value: InstitutionLifecycleAction.activate,
            icon: Icons.play_circle_outline_rounded,
            label: 'Ativar',
          ),
        if (!archived && item.status != InstitutionStatus.inactive)
          const CoeloAdminFlyoutItem(
            value: InstitutionLifecycleAction.inactivate,
            icon: Icons.pause_circle_outline_rounded,
            label: 'Inativar',
          ),
        if (!archived)
          const CoeloAdminFlyoutItem(
            value: InstitutionLifecycleAction.delete,
            icon: Icons.delete_outline,
            label: 'Excluir',
            startsGroup: true,
            tone: CoeloAdminFlyoutTone.negative,
          ),
      ],
      onSelected: onSelected,
      builder: (context, controller) => IconButton(
        key: Key('institution-lifecycle-${item.id}'),
        tooltip: 'Ações da instituição',
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.more_horiz_rounded),
        iconSize: CoeloSize.iconSm,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Motivo obrigatório para transições restritivas (spec 066 §4). Devolve o
/// texto ou nulo se o operador desistir.
Future<String?> showInstitutionLifecycleReasonDialog(
  BuildContext context, {
  required InstitutionLifecycleAction action,
  required InstitutionDirectoryItem item,
}) => showDialog<String>(
  context: context,
  barrierColor: context.coeloScrim,
  builder: (_) => _LifecycleReasonDialog(action: action, item: item),
);

final class _LifecycleReasonDialog extends StatefulWidget {
  const _LifecycleReasonDialog({required this.action, required this.item});

  final InstitutionLifecycleAction action;
  final InstitutionDirectoryItem item;

  @override
  State<_LifecycleReasonDialog> createState() => _LifecycleReasonDialogState();
}

final class _LifecycleReasonDialogState extends State<_LifecycleReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDelete = widget.action == InstitutionLifecycleAction.delete;
    final item = widget.item;
    return CoeloAdminDialogShell(
      dialogKey: const Key('institution-lifecycle-reason-dialog'),
      title: isDelete ? 'Excluir ${item.publicName}?' : 'Inativar ${item.publicName}?',
      closeTooltip: 'Fechar',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isDelete
                ? 'Sem vínculos a instituição é removida de vez; com vínculos ela é '
                      'arquivada e some das telas, mantendo histórico, unidades e mídia.'
                : 'A instituição some das listas e das opções de seleção, sem alterar '
                      'unidades, turmas e pessoas. Pode ser reativada depois.',
          ),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloFormTextField(
            key: const Key('institution-lifecycle-reason'),
            controller: _controller,
            labelText: 'Motivo',
            hintText: isDelete ? 'Ex.: criada em duplicidade' : 'Ex.: encerramento do contrato',
            prefixIcon: Icons.edit_note_outlined,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      secondaryAction: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      primaryAction: FilledButton(
        key: const Key('institution-lifecycle-confirm'),
        onPressed: _controller.text.trim().isEmpty
            ? null
            : () => Navigator.of(context).pop(_controller.text.trim()),
        style: isDelete ? coeloDestructiveFilledButtonStyle(context) : null,
        child: Text(isDelete ? 'Excluir' : 'Inativar'),
      ),
    );
  }
}
