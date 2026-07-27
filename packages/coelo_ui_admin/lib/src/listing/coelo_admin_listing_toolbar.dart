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
        final filtersGroup = Wrap(
          spacing: CoeloSpacing.space3,
          runSpacing: CoeloSpacing.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [search, ...filters],
        );
        final actionsGroup = Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        );

        if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              filtersGroup,
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
            Expanded(child: filtersGroup),
            if (actions.isNotEmpty) ...[const SizedBox(width: CoeloSpacing.space4), actionsGroup],
          ],
        );
      },
    );
  }
}
