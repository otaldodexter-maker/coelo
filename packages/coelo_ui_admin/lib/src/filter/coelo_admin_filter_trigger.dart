import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Shared directory-filter appearance; each menu owns its selection behavior.
final class CoeloAdminFilterTrigger extends StatelessWidget {
  const CoeloAdminFilterTrigger({
    required this.label,
    required this.menuOpen,
    required this.focusNode,
    required this.onPressed,
    super.key,
  });
  final String label;
  final bool menuOpen;
  final FocusNode focusNode;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OutlinedButton(
      focusNode: focusNode,
      onPressed: onPressed,
      style:
          OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(CoeloSize.touchMin),
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
            shape: const StadiumBorder(),
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => menuOpen ? colors.primaryContainer : Colors.transparent,
            ),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              final active =
                  menuOpen ||
                  states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused) ||
                  states.contains(WidgetState.pressed);
              return active ? colors.primary : colors.onSurfaceVariant;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              final focused = menuOpen || states.contains(WidgetState.focused);
              return BorderSide(
                color: focused ? colors.primary : colors.outlineVariant,
                width: focused ? 2 : 1,
              );
            }),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
          ),
      child: Row(
        children: [
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: CoeloSpacing.space1),
          const Icon(Icons.arrow_drop_down_rounded),
        ],
      ),
    );
  }
}
