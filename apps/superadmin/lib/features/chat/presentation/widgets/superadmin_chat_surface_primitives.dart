import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class SuperadminChatCloseButton extends StatelessWidget {
  const SuperadminChatCloseButton({required this.tooltip, required this.onPressed, super.key});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: colors.error,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.square(CoeloSize.touchMin)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
              ? colors.errorContainer
              : Colors.transparent,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      icon: const Icon(Icons.close_rounded),
    );
  }
}

final class SuperadminChatMenuAction {
  const SuperadminChatMenuAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
    this.dividerBefore = false,
    this.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive;
  final bool dividerBefore;
  final Key? key;
}

final class SuperadminChatActionMenu extends StatelessWidget {
  const SuperadminChatActionMenu({required this.tooltip, required this.actions, super.key});

  final String tooltip;
  final List<SuperadminChatMenuAction> actions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(4),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(CoeloSpacing.space1)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoeloRadius.md),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      menuChildren: [
        for (final action in actions) ...[
          if (action.dividerBefore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: CoeloSpacing.space1),
              child: Divider(height: 1),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.spaceHalf),
            child: MenuItemButton(
              key: action.key,
              onPressed: action.onPressed,
              leadingIcon: Icon(action.icon),
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(200, CoeloSize.touchMin)),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => action.destructive
                      ? colors.error
                      : states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                      ? colors.primary
                      : colors.onSurface,
                ),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  final highlighted =
                      states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                  if (!highlighted) return Colors.transparent;
                  return action.destructive ? colors.errorContainer : colors.primaryContainer;
                }),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
              child: Text(action.label),
            ),
          ),
        ],
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: tooltip,
        onPressed: controller.isOpen ? controller.close : controller.open,
        icon: const Icon(Icons.more_vert_rounded),
      ),
    );
  }
}
