import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class SuperadminUnderlineTab<T> {
  const SuperadminUnderlineTab({required this.value, required this.label});

  final T value;
  final String label;
}

/// App-local selector for lightweight directory categories.
final class SuperadminUnderlineTabs<T> extends StatelessWidget {
  const SuperadminUnderlineTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<SuperadminUnderlineTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in tabs)
              Semantics(
                button: true,
                selected: tab.value == selected,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelected(tab.value),
                    overlayColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)) {
                        return colors.primaryContainer.withValues(alpha: .48);
                      }
                      return Colors.transparent;
                    }),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: tab.value == selected ? colors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        tab.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: tab.value == selected ? colors.primary : colors.onSurfaceVariant,
                          fontWeight: tab.value == selected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
