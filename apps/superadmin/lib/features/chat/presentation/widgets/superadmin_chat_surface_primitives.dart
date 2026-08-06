import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
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
    return CoeloAdminFlyout<SuperadminChatMenuAction>(
      items: [
        for (final action in actions)
          CoeloAdminFlyoutItem(
            value: action,
            label: action.label,
            icon: action.icon,
            startsGroup: action.dividerBefore,
            tone: action.destructive
                ? CoeloAdminFlyoutTone.negative
                : CoeloAdminFlyoutTone.standard,
          ),
      ],
      onSelected: (action) => action.onPressed(),
      builder: (context, controller) => IconButton(
        tooltip: tooltip,
        onPressed: controller.isOpen ? controller.close : controller.open,
        icon: const Icon(Icons.more_vert_rounded),
      ),
    );
  }
}
