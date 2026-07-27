import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef CoeloAdminKanbanItemsForStatus<T, S> = List<T> Function(S status);
typedef CoeloAdminKanbanItemBuilder<T> = Widget Function(BuildContext context, T item);
typedef CoeloAdminKanbanAccept<T, S> = void Function(T item, S targetStatus);

/// A domain-neutral, horizontally scrollable operational Kanban.
final class CoeloAdminKanbanBoard<T extends Object, S> extends StatefulWidget {
  const CoeloAdminKanbanBoard({
    required this.statuses,
    required this.statusLabel,
    required this.itemsForStatus,
    required this.itemBuilder,
    required this.onItemAccepted,
    this.emptyLaneBuilder,
    this.selectedStatus,
    this.onSelectedStatusChanged,
    super.key,
  });

  final List<S> statuses;
  final String Function(S status) statusLabel;
  final CoeloAdminKanbanItemsForStatus<T, S> itemsForStatus;
  final CoeloAdminKanbanItemBuilder<T> itemBuilder;
  final CoeloAdminKanbanAccept<T, S> onItemAccepted;
  final Widget Function(BuildContext context, S status)? emptyLaneBuilder;
  final S? selectedStatus;
  final ValueChanged<S>? onSelectedStatusChanged;

  @override
  State<CoeloAdminKanbanBoard<T, S>> createState() => _CoeloAdminKanbanBoardState<T, S>();
}

final class _CoeloAdminKanbanBoardState<T extends Object, S>
    extends State<CoeloAdminKanbanBoard<T, S>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.statuses.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          final selected = widget.selectedStatus ?? widget.statuses.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: CoeloSize.touchMin,
                child: DropdownButton<S>(
                  key: const Key('coelo-admin-kanban-status-selector'),
                  value: selected,
                  isExpanded: true,
                  items: [
                    for (final status in widget.statuses)
                      DropdownMenuItem<S>(value: status, child: Text(widget.statusLabel(status))),
                  ],
                  onChanged: (status) {
                    if (status != null) {
                      widget.onSelectedStatusChanged?.call(status);
                    }
                  },
                ),
              ),
              const SizedBox(height: CoeloSpacing.space3),
              Expanded(child: _lane(context, selected, constraints.maxWidth)),
            ],
          );
        }

        final gaps = CoeloSpacing.space3 * (widget.statuses.length - 1);
        final fittedLaneWidth = (constraints.maxWidth - gaps) / widget.statuses.length;
        final laneWidth = math.max(280.0, fittedLaneWidth);
        final contentWidth = laneWidth * widget.statuses.length + gaps;

        return ScrollConfiguration(
          key: const Key('coelo-admin-kanban-scroll-configuration'),
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: const {
              PointerDeviceKind.mouse,
              PointerDeviceKind.touch,
              PointerDeviceKind.stylus,
              PointerDeviceKind.trackpad,
            },
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              key: const Key('coelo-admin-kanban-scroll'),
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < widget.statuses.length; index++) ...[
                      SizedBox(
                        width: laneWidth,
                        child: _lane(context, widget.statuses[index], laneWidth),
                      ),
                      if (index != widget.statuses.length - 1)
                        const SizedBox(width: CoeloSpacing.space3),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _lane(BuildContext context, S status, double width) {
    final items = widget.itemsForStatus(status);
    final colors = Theme.of(context).colorScheme;
    return DragTarget<T>(
      onAcceptWithDetails: (details) => widget.onItemAccepted(details.data, status),
      builder: (context, candidates, rejected) {
        final accepting = candidates.isNotEmpty;
        return Semantics(
          container: true,
          label: '${widget.statusLabel(status)}, ${items.length} itens',
          child: DecoratedBox(
            key: ValueKey<(String, S)>(('coelo-admin-kanban-lane', status)),
            decoration: BoxDecoration(
              color: accepting ? colors.primaryContainer : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              border: Border.all(color: accepting ? colors.primary : colors.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.statusLabel(status),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: CoeloSpacing.space6,
                            minHeight: CoeloSpacing.space6,
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space2),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(CoeloRadius.full),
                          ),
                          child: Text(
                            '${items.length}',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CoeloSpacing.space3),
                  Expanded(
                    child: items.isEmpty
                        ? widget.emptyLaneBuilder?.call(context, status) ??
                              Center(
                                child: Text(
                                  'Nenhum item',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                                ),
                              )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space3),
                            itemBuilder: (context, index) =>
                                widget.itemBuilder(context, items[index]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
