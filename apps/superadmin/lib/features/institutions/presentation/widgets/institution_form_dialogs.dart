import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

Future<bool> showInstitutionExitDialog(
  BuildContext context, {
  String entityLabel = 'instituição',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
    builder: (context) => CoeloAdminDialogShell(
      dialogKey: const Key('institution-confirm-exit-dialog'),
      title: 'Sair sem salvar?',
      closeTooltip: 'Fechar confirmação',
      closeButtonKey: const Key('institution-dialog-close'),
      body: Text('As alterações feitas nesta $entityLabel serão descartadas.'),
      secondaryAction: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Continuar editando'),
      ),
      primaryAction: FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Sair sem salvar'),
      ),
    ),
  );
  return result ?? false;
}

Future<bool> showInstitutionSubscriptionDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
        builder: (context) => CoeloAdminDialogShell(
          dialogKey: const Key('institution-subscription-dialog'),
          title: title,
          closeTooltip: 'Fechar confirmação',
          closeButtonKey: const Key('institution-dialog-close'),
          body: Text(message),
          secondaryAction: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          primaryAction: FilledButton(
            key: const Key('institution-subscription-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ),
      ) ??
      false;
}
