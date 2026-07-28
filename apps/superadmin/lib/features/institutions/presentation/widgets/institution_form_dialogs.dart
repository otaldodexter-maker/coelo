import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

Future<bool> showInstitutionExitDialog(
  BuildContext context, {
  String entityLabel = 'instituição',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
    builder: (context) => _InstitutionDialog(
      dialogKey: Key('institution-confirm-exit-dialog'),
      title: 'Sair sem salvar?',
      message: 'As alterações feitas nesta $entityLabel serão descartadas.',
      confirmLabel: 'Sair sem salvar',
      confirmValue: true,
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
        builder: (context) => _SubscriptionDialog(title: title, message: message),
      ) ??
      false;
}

final class _InstitutionDialog extends StatelessWidget {
  const _InstitutionDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmValue,
    required this.dialogKey,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool confirmValue;
  final Key dialogKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      key: dialogKey,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DialogHeader(title: title),
              const SizedBox(height: CoeloSpacing.space4),
              Text(message),
              const SizedBox(height: CoeloSpacing.space5),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Continuar editando'),
                    ),
                  ),
                  const SizedBox(width: CoeloSpacing.space3),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(confirmValue),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _SubscriptionDialog extends StatefulWidget {
  const _SubscriptionDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  State<_SubscriptionDialog> createState() => _SubscriptionDialogState();
}

final class _SubscriptionDialogState extends State<_SubscriptionDialog> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      key: const Key('institution-subscription-dialog'),
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DialogHeader(title: widget.title),
              const SizedBox(height: CoeloSpacing.space4),
              Text(widget.message),
              const SizedBox(height: CoeloSpacing.space5),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: CoeloSpacing.space2,
                runSpacing: CoeloSpacing.space2,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    key: const Key('institution-subscription-confirm'),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall)),
        IconButton(
          key: const Key('institution-dialog-close'),
          tooltip: 'Fechar confirmação',
          onPressed: () => Navigator.of(context).pop(),
          style:
              IconButton.styleFrom(
                minimumSize: const Size.square(CoeloSize.touchMin),
                maximumSize: const Size.square(CoeloSize.touchMin),
                foregroundColor: colors.error,
                shape: const CircleBorder(),
              ).copyWith(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                      ? colors.errorContainer
                      : Colors.transparent,
                ),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}
