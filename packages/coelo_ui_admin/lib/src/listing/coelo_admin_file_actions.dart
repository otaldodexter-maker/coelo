import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

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
  final VoidCallback onPressed;
  final Key? key;
}

/// Shared file operation menu for administrative listing toolbars.
final class CoeloAdminFileActions extends StatelessWidget {
  const CoeloAdminFileActions({required this.actions, this.compact = false, super.key});

  final List<CoeloAdminFileAction> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compactMenuOffset = MediaQuery.sizeOf(context).width < CoeloBreakpoints.medium.minWidth
        ? 0.0
        : -128.0;

    return MenuAnchor(
      alignmentOffset: Offset(compact ? compactMenuOffset : -80, CoeloSpacing.space2),
      style: MenuStyle(
        alignment: AlignmentDirectional.bottomStart,
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        elevation: const WidgetStatePropertyAll(CoeloElevation.level2),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(CoeloSpacing.space2)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      menuChildren: [
        for (final action in actions)
          SizedBox(
            width: compact ? 176 : null,
            child: MenuItemButton(
              key: action.key,
              style: _menuItemStyle(colors),
              onPressed: action.onPressed,
              leadingIcon: Icon(action.icon),
              child: Text(action.label),
            ),
          ),
      ],
      builder: (context, controller, child) {
        void toggle() => controller.isOpen ? controller.close() : controller.open();
        if (compact) {
          return IconButton(
            key: const Key('coelo-admin-files-action'),
            tooltip: 'Arquivos',
            style: IconButton.styleFrom(minimumSize: const Size.square(CoeloSize.touchMin)),
            onPressed: toggle,
            icon: const Icon(Icons.folder_open_outlined),
          );
        }
        return OutlinedButton.icon(
          key: const Key('coelo-admin-files-action'),
          onPressed: toggle,
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Arquivos'),
        );
      },
    );
  }
}

ButtonStyle _menuItemStyle(ColorScheme colors) {
  return MenuItemButton.styleFrom(
    minimumSize: const Size.fromHeight(CoeloSize.touchMin),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
  ).copyWith(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return highlighted ? colors.primary : colors.onSurfaceVariant;
    }),
    iconColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return highlighted ? colors.primary : colors.onSurfaceVariant;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return highlighted ? colors.primaryContainer : Colors.transparent;
    }),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}
