import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class CoeloAdminDialogShell extends StatelessWidget {
  const CoeloAdminDialogShell({
    required this.title,
    required this.body,
    required this.primaryAction,
    this.secondaryAction,
    this.maxWidth = 520,
    this.closeTooltip = 'Fechar',
    this.dialogKey,
    this.closeButtonKey,
    this.onClose,
    super.key,
  });

  final String title;
  final Widget body;
  final Widget primaryAction;
  final Widget? secondaryAction;
  final double maxWidth;
  final String closeTooltip;
  final Key? dialogKey;
  final Key? closeButtonKey;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final usesExpandedText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        CoeloSpacing.space6,
        CoeloSpacing.space4,
        CoeloSpacing.space3,
        CoeloSpacing.space2,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall)),
          IconButton(
            key: closeButtonKey,
            tooltip: closeTooltip,
            onPressed: onClose ?? () => Navigator.of(context).pop(),
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
      ),
    );
    final divider = Divider(height: 1, color: colors.outlineVariant);
    final footer = Padding(
      padding: const EdgeInsets.fromLTRB(
        CoeloSpacing.space6,
        0,
        CoeloSpacing.space6,
        CoeloSpacing.space6,
      ),
      child: _DialogFooter(primaryAction: primaryAction, secondaryAction: secondaryAction),
    );
    final normalBody = SingleChildScrollView(
      padding: const EdgeInsets.all(CoeloSpacing.space6),
      child: body,
    );
    return Dialog(
      key: dialogKey,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: viewportHeight - (CoeloSpacing.space6 * 2),
        ),
        child: usesExpandedText
            ? ListView(
                shrinkWrap: true,
                children: [
                  header,
                  divider,
                  Padding(padding: const EdgeInsets.all(CoeloSpacing.space6), child: body),
                  footer,
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  divider,
                  Flexible(child: normalBody),
                  footer,
                ],
              ),
      ),
    );
  }
}

final class _DialogFooter extends StatelessWidget {
  const _DialogFooter({required this.primaryAction, required this.secondaryAction});

  final Widget primaryAction;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final secondary = secondaryAction;
    if (secondary == null) {
      return ConstrainedBox(
        key: const Key('coelo-admin-dialog-footer'),
        constraints: const BoxConstraints(minWidth: double.infinity, minHeight: CoeloSize.touchMin),
        child: primaryAction,
      );
    }
    return Row(
      key: const Key('coelo-admin-dialog-footer'),
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
            child: secondary,
          ),
        ),
        const SizedBox(width: CoeloSpacing.space3),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
            child: primaryAction,
          ),
        ),
      ],
    );
  }
}
