import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../overlay/coelo_admin_flyout.dart';

@immutable
final class CoeloAdminFileAction {
  const CoeloAdminFileAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.key,
  });

  final String label;
  final IconData icon;

  /// Null keeps the operation visible while communicating that it is not yet available.
  final VoidCallback? onPressed;
  final Key? key;
}

/// Shared file operation menu for administrative listing toolbars.
final class CoeloAdminFileActions extends StatelessWidget {
  const CoeloAdminFileActions({required this.actions, this.compact = false, super.key});

  final List<CoeloAdminFileAction> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final compactMenuOffset = MediaQuery.sizeOf(context).width < CoeloBreakpoints.medium.minWidth
        ? 0.0
        : -160.0;

    return CoeloAdminFlyout<CoeloAdminFileAction>(
      items: [
        for (final action in actions)
          CoeloAdminFlyoutItem<CoeloAdminFileAction>(
            value: action,
            label: action.label,
            icon: action.icon,
            semanticLabel: action.onPressed == null
                ? '${action.label}, indisponível'
                : action.label,
            enabled: action.onPressed != null,
          ),
      ],
      onSelected: (action) => action.onPressed?.call(),
      itemWidth: 220,
      alignmentOffset: Offset(compact ? compactMenuOffset : -80, CoeloSpacing.spaceHalf),
      builder: (context, controller) {
        void toggle() => controller.isOpen ? controller.close() : controller.open();
        if (compact) {
          final colors = Theme.of(context).colorScheme;
          return IconButton(
            key: const Key('coelo-admin-files-action'),
            tooltip: 'Arquivos',
            style: ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(colors.primary),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
                  return colors.primaryContainer;
                }
                return Colors.transparent;
              }),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              minimumSize: const WidgetStatePropertyAll(Size.square(CoeloSize.touchMin)),
            ),
            onPressed: toggle,
            icon: const Icon(Icons.folder_open_outlined),
          );
        }
        final colors = Theme.of(context).colorScheme;
        return OutlinedButton.icon(
          key: const Key('coelo-admin-files-action'),
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(colors.primary),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
                return colors.primaryContainer;
              }
              return Colors.transparent;
            }),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
          onPressed: toggle,
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Arquivos'),
        );
      },
    );
  }
}
