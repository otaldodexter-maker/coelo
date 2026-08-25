import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class CoeloAdminListingToolbar extends StatelessWidget {
  const CoeloAdminListingToolbar({
    required this.search,
    required this.filters,
    required this.actions,
    super.key,
  });

  final Widget search;
  final List<Widget> filters;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final actionsGroup = Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        );

        if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth || textScale >= 2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: double.infinity, child: search),
              if (filters.isNotEmpty) ...[
                const SizedBox(height: CoeloSpacing.space2),
                _EqualWidthControlGrid(controls: filters, maximumColumns: textScale >= 2 ? 1 : 2),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: CoeloSpacing.space3),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: CoeloSpacing.space2),
                    child: Align(alignment: Alignment.centerLeft, child: actionsGroup),
                  ),
                ),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _EqualWidthControlGrid(controls: [search, ...filters])),
            if (actions.isNotEmpty) ...[const SizedBox(width: CoeloSpacing.space4), actionsGroup],
          ],
        );
      },
    );
  }
}

final class _EqualWidthControlGrid extends StatelessWidget {
  const _EqualWidthControlGrid({required this.controls, this.maximumColumns});

  final List<Widget> controls;
  final int? maximumColumns;

  @override
  Widget build(BuildContext context) {
    if (controls.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = CoeloSpacing.space3;
        const minimumFunctionalWidth = CoeloSize.touchMin * 3 + CoeloSpacing.space4;
        final fittingColumns = ((constraints.maxWidth + gap) / (minimumFunctionalWidth + gap))
            .floor()
            .clamp(1, controls.length);
        final columnCount = maximumColumns == null
            ? fittingColumns
            : fittingColumns.clamp(1, maximumColumns!);
        final rows = <Widget>[];
        for (var start = 0; start < controls.length; start += columnCount) {
          final end = (start + columnCount).clamp(0, controls.length);
          final rowControls = controls.sublist(start, end);
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < rowControls.length; index++) ...[
                  if (index > 0) const SizedBox(width: gap),
                  Expanded(child: rowControls[index]),
                ],
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) const SizedBox(height: CoeloSpacing.space2),
              rows[index],
            ],
          ],
        );
      },
    );
  }
}
