import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/data/entity_lifecycle.dart';
import '../../../shared/presentation/widgets/entity_lifecycle_runner.dart';
import '../domain/person_directory.dart';
import '../domain/person_suspension.dart';

enum PersonSuspensionAction { edit, suspend, reactivate }

/// ⋯ do card de pessoa (spec 066 §3): Editar, Suspender por período… ou
/// Reativar. Pessoa técnica (`service`) não tem menu — o servidor recusa.
final class PersonSuspensionMenu extends StatelessWidget {
  const PersonSuspensionMenu({
    super.key,
    required this.item,
    required this.onSelected,
    this.canEdit = false,
  });

  final PersonDirectoryItem item;
  final bool canEdit;
  final ValueChanged<PersonSuspensionAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheduled = item.suspendedFrom != null;
    return CoeloAdminFlyout<PersonSuspensionAction>(
      items: [
        if (canEdit)
          const CoeloAdminFlyoutItem(
            value: PersonSuspensionAction.edit,
            icon: Icons.edit_outlined,
            label: 'Editar',
          ),
        if (!scheduled)
          const CoeloAdminFlyoutItem(
            value: PersonSuspensionAction.suspend,
            icon: Icons.pause_circle_outline_rounded,
            label: 'Suspender por período…',
            tone: CoeloAdminFlyoutTone.negative,
          )
        else
          const CoeloAdminFlyoutItem(
            value: PersonSuspensionAction.reactivate,
            icon: Icons.play_circle_outline_rounded,
            label: 'Reativar',
          ),
      ],
      onSelected: onSelected,
      builder: (context, controller) => IconButton(
        key: Key('person-suspension-${item.id}'),
        tooltip: 'Ações de ${item.displayName}',
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.more_horiz_rounded),
        iconSize: CoeloSize.iconSm,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Rótulo curto do estado de suspensão para o card (nulo quando não há).
String? personSuspensionLabel(PersonDirectoryItem item) {
  final from = item.suspendedFrom;
  if (from == null) return null;
  final until = item.suspendedUntil;
  if (!item.suspendedNow && from.isAfter(DateTime.now().toUtc())) {
    return 'Suspensão a partir de ${CoeloDateField.format(from.toLocal())}';
  }
  if (!item.suspendedNow) return null;
  return until == null
      ? 'Suspensa até reativar'
      : 'Suspensa até ${CoeloDateField.format(until.toLocal())}';
}

/// Executa a ação do [PersonSuspensionMenu]: pede motivo e fim opcional para
/// suspender, chama o comando, dá feedback e recarrega pela [reload].
Future<void> runPersonSuspension(
  BuildContext context, {
  required PersonSuspensionCommands commands,
  required PersonDirectoryItem item,
  required PersonSuspensionAction action,
  required Future<void> Function() reload,
  ValueChanged<String>? onEdit,
}) async {
  if (action == PersonSuspensionAction.edit) {
    onEdit?.call(item.id);
    return;
  }
  PersonSuspensionInput? input;
  if (action == PersonSuspensionAction.suspend) {
    input = await showDialog<PersonSuspensionInput>(
      context: context,
      barrierColor: context.coeloScrim,
      builder: (_) => _SuspendDialog(personName: item.displayName),
    );
    if (input == null || !context.mounted) return;
  }
  final messenger = ScaffoldMessenger.of(context);
  void feedback(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  try {
    if (action == PersonSuspensionAction.suspend) {
      final result = await commands.suspend(
        item.id,
        requestId: entityLifecycleRequestId(),
        reason: input!.reason,
        until: input.until,
      );
      feedback(
        result.suspendedUntil == null
            ? '${item.displayName} suspensa até reativar.'
            : '${item.displayName} suspensa até '
                  '${CoeloDateField.format(result.suspendedUntil!.toLocal())}.',
      );
    } else {
      await commands.reactivate(item.id, requestId: entityLifecycleRequestId());
      feedback('${item.displayName} reativada.');
    }
  } on EntityLifecycleValidationException catch (error) {
    feedback(error.message);
  } on EntityLifecycleUnauthorizedException {
    feedback('Você não tem permissão para alterar esta pessoa.');
  } on Object {
    feedback('Não foi possível concluir a operação.');
  }
  await reload();
}

final class PersonSuspensionInput {
  const PersonSuspensionInput({required this.reason, this.until});
  final String reason;
  final DateTime? until;
}

final class _SuspendDialog extends StatefulWidget {
  const _SuspendDialog({required this.personName});
  final String personName;

  @override
  State<_SuspendDialog> createState() => _SuspendDialogState();
}

final class _SuspendDialogState extends State<_SuspendDialog> {
  final _reason = TextEditingController();
  DateTime? _until;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    return CoeloAdminDialogShell(
      dialogKey: const Key('person-suspension-dialog'),
      title: 'Suspender ${widget.personName}?',
      closeTooltip: 'Fechar',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'A conta não entra no app enquanto a suspensão valer; vínculos e histórico '
            'ficam como estão. Sem data de fim, vale até alguém reativar.',
          ),
          const SizedBox(height: CoeloSpacing.space4),
          Row(
            children: [
              Expanded(
                child: CoeloDateField(
                  key: const Key('person-suspension-until'),
                  labelText: 'Fim da suspensão (opcional)',
                  value: _until,
                  emptyLabel: 'Até reativar',
                  firstDate: today.add(const Duration(days: 1)),
                  lastDate: DateTime(today.year + 5),
                  onChanged: (value) => setState(() => _until = value),
                ),
              ),
              if (_until != null)
                IconButton(
                  key: const Key('person-suspension-until-clear'),
                  tooltip: 'Sem data de fim',
                  onPressed: () => setState(() => _until = null),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloFormTextField(
            key: const Key('person-suspension-reason'),
            controller: _reason,
            labelText: 'Motivo',
            hintText: 'Ex.: afastamento até a conclusão da apuração',
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
        key: const Key('person-suspension-confirm'),
        onPressed: _reason.text.trim().isEmpty
            ? null
            : () => Navigator.of(context).pop(
                PersonSuspensionInput(
                  reason: _reason.text.trim(),
                  // A suspensão vale até o fim do dia local escolhido.
                  until: _until == null
                      ? null
                      : DateTime(_until!.year, _until!.month, _until!.day + 1),
                ),
              ),
        style: coeloDestructiveFilledButtonStyle(context),
        child: const Text('Suspender'),
      ),
    );
  }
}
