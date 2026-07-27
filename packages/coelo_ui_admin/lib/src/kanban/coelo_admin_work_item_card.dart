import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Presentation-only card for operational boards.
///
/// Consumers should provide [trailingMenu] as the keyboard and touch
/// alternative for any drag-only state transition.
final class CoeloAdminWorkItemCard<T extends Object> extends StatefulWidget {
  const CoeloAdminWorkItemCard({
    required this.eyebrow,
    required this.title,
    required this.summary,
    required this.onTap,
    this.onDoubleTap,
    this.metadata = const [],
    this.indicators,
    this.assignees,
    this.trailingMenu,
    this.dragData,
    this.dragFeedback,
    this.focusNode,
    this.selected = false,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String summary;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final List<String> metadata;
  final Widget? indicators;
  final Widget? assignees;
  final Widget? trailingMenu;
  final T? dragData;
  final Widget? dragFeedback;
  final FocusNode? focusNode;
  final bool selected;

  @override
  State<CoeloAdminWorkItemCard<T>> createState() => _CoeloAdminWorkItemCardState<T>();
}

final class _CoeloAdminWorkItemCardState<T extends Object>
    extends State<CoeloAdminWorkItemCard<T>> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final card = _card(context);
    final data = widget.dragData;
    if (data == null) {
      return card;
    }
    return LongPressDraggable<T>(
      data: data,
      feedback:
          widget.dragFeedback ??
          Material(
            color: Colors.transparent,
            child: SizedBox(width: 320, child: _card(context, interactive: false, elevated: true)),
          ),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
    );
  }

  Widget _card(BuildContext context, {bool interactive = true, bool elevated = false}) {
    final colors = Theme.of(context).colorScheme;
    final highlighted = widget.selected || _hovered || _focused;
    return Semantics(
      button: interactive,
      selected: widget.selected,
      child: MouseRegion(
        cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: interactive ? (_) => setState(() => _hovered = true) : null,
        onExit: interactive ? (_) => setState(() => _hovered = false) : null,
        child: Material(
          color: colors.surface,
          elevation: elevated ? CoeloElevation.level2 : CoeloElevation.level0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            side: BorderSide(color: highlighted ? colors.primary : colors.outlineVariant),
          ),
          child: InkWell(
            focusNode: interactive ? widget.focusNode : null,
            onTap: interactive ? widget.onTap : null,
            onDoubleTap: interactive ? widget.onDoubleTap : null,
            onFocusChange: interactive ? (value) => setState(() => _focused = value) : null,
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused) ||
                  states.contains(WidgetState.pressed)) {
                return colors.primaryContainer.withValues(alpha: 0.45);
              }
              return Colors.transparent;
            }),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
              child: Padding(
                padding: const EdgeInsets.all(CoeloSpacing.space3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.eyebrow,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                        if (widget.trailingMenu != null) widget.trailingMenu!,
                      ],
                    ),
                    const SizedBox(height: CoeloSpacing.space2),
                    Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: CoeloSpacing.space1),
                    Text(
                      widget.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    for (final value in widget.metadata) ...[
                      const SizedBox(height: CoeloSpacing.space2),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                    if (widget.assignees != null || widget.indicators != null) ...[
                      const SizedBox(height: CoeloSpacing.space3),
                      Row(
                        children: [
                          if (widget.assignees != null)
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: widget.assignees,
                              ),
                            )
                          else
                            const Spacer(),
                          if (widget.indicators != null) widget.indicators!,
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
