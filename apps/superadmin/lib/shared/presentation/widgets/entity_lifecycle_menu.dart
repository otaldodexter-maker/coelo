import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

enum EntityLifecycleAction { edit, activate, inactivate, delete }

/// Estado resumido de uma entidade para o menu de ciclo de vida (spec 066).
enum EntityLifecycleState { active, inactive, archived, other }

/// ⋯ de ciclo de vida (spec 066, OQ-033 opção B) para instituição, unidade e
/// turma: Editar, Ativar/Inativar, Excluir. Só oferece o que o estado permite;
/// a decisão final é sempre do servidor.
final class EntityLifecycleMenu extends StatelessWidget {
  const EntityLifecycleMenu({
    super.key,
    required this.keyPrefix,
    required this.entityId,
    required this.state,
    required this.entityLabel,
    required this.onSelected,
    this.canEdit = false,
  });

  /// Prefixo das chaves de teste (`institution`, `unit`, `group`).
  final String keyPrefix;
  final String entityId;
  final EntityLifecycleState state;
  final String entityLabel;
  final bool canEdit;
  final ValueChanged<EntityLifecycleAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final archived = state == EntityLifecycleState.archived;
    return CoeloAdminFlyout<EntityLifecycleAction>(
      items: [
        if (canEdit) CoeloAdminEntityActions.edit(EntityLifecycleAction.edit),
        if (!archived && state != EntityLifecycleState.active)
          CoeloAdminEntityActions.activate(EntityLifecycleAction.activate),
        if (!archived && state != EntityLifecycleState.inactive)
          CoeloAdminEntityActions.inactivate(EntityLifecycleAction.inactivate),
        if (!archived)
          CoeloAdminEntityActions.delete(EntityLifecycleAction.delete, startsGroup: true),
      ],
      onSelected: onSelected,
      builder: (context, controller) => CoeloAdminEntityActionsTrigger(
        key: Key('$keyPrefix-lifecycle-$entityId'),
        controller: controller,
        tooltip: 'Ações de $entityLabel',
      ),
    );
  }
}

/// Motivo obrigatório para inativar/excluir (spec 066 §4). Devolve o texto ou
/// nulo se o operador desistir.
Future<String?> showEntityLifecycleReasonDialog(
  BuildContext context, {
  required String keyPrefix,
  required EntityLifecycleAction action,
  required String entityLabel,
  required String entityName,
}) => showDialog<String>(
  context: context,
  barrierColor: context.coeloScrim,
  builder: (_) => _ReasonDialog(
    keyPrefix: keyPrefix,
    action: action,
    entityLabel: entityLabel,
    entityName: entityName,
  ),
);

final class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.keyPrefix,
    required this.action,
    required this.entityLabel,
    required this.entityName,
  });

  final String keyPrefix;
  final EntityLifecycleAction action;
  final String entityLabel;
  final String entityName;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

final class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDelete = widget.action == EntityLifecycleAction.delete;
    final label = widget.entityLabel;
    return CoeloAdminDialogShell(
      dialogKey: Key('${widget.keyPrefix}-lifecycle-reason-dialog'),
      title: isDelete ? 'Excluir ${widget.entityName}?' : 'Inativar ${widget.entityName}?',
      closeTooltip: 'Fechar',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isDelete
                ? 'Sem vínculos a $label é removida de vez; com vínculos ela é arquivada e '
                      'some das telas, mantendo histórico, o que está dentro dela e a mídia.'
                : 'A $label some das listas e das opções de seleção, sem alterar o que está '
                      'dentro dela. Pode ser reativada depois.',
          ),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloFormTextField(
            key: Key('${widget.keyPrefix}-lifecycle-reason'),
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
        key: Key('${widget.keyPrefix}-lifecycle-confirm'),
        onPressed: _controller.text.trim().isEmpty
            ? null
            : () => Navigator.of(context).pop(_controller.text.trim()),
        style: isDelete ? coeloDestructiveFilledButtonStyle(context) : null,
        child: Text(isDelete ? 'Excluir' : 'Inativar'),
      ),
    );
  }
}
