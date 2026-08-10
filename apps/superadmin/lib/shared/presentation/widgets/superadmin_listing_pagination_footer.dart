import 'dart:ui';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// App-local composition approved by the Institutions listing.
///
/// It deliberately stays private to Superadmin and does not create a public
/// Design System API.
final class SuperadminListingPaginationFooter extends StatelessWidget {
  const SuperadminListingPaginationFooter({
    required this.horizontalPadding,
    required this.child,
    this.semanticKey,
    this.compactCurrentPage,
    this.compactTotalPages,
    this.compactOnPrevious,
    this.compactOnNext,
    super.key,
  }) : assert(
         (compactCurrentPage == null) == (compactTotalPages == null),
         'Compact current and total pages must be provided together.',
       ),
       assert(compactCurrentPage == null || compactCurrentPage >= 1),
       assert(
         compactCurrentPage == null ||
             compactTotalPages == null ||
             compactTotalPages >= compactCurrentPage,
       );

  final double horizontalPadding;
  final Widget child;
  final Key? semanticKey;

  final int? compactCurrentPage;
  final int? compactTotalPages;
  final VoidCallback? compactOnPrevious;
  final VoidCallback? compactOnNext;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRect(
      key: semanticKey,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: CoeloSpacing.space3, sigmaY: CoeloSpacing.space3),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            CoeloSpacing.space3,
            horizontalPadding,
            CoeloSpacing.space3,
          ),
          decoration: BoxDecoration(
            color: colors.surface.withValues(
              alpha: Theme.brightnessOf(context) == Brightness.light ? 0.84 : 0.88,
            ),
          ),
          child: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth + horizontalPadding * 2 <
                        CoeloBreakpoints.medium.minWidth &&
                    compactCurrentPage != null &&
                    compactTotalPages != null;
                if (!compact) return child;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CompactPageAction(
                      label: 'P\u00e1gina anterior',
                      icon: Icons.chevron_left_rounded,
                      onPressed: compactOnPrevious,
                    ),
                    const SizedBox(width: CoeloSpacing.space1),
                    Flexible(
                      child: Text(
                        'P\u00e1gina $compactCurrentPage de $compactTotalPages',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(width: CoeloSpacing.space1),
                    _CompactPageAction(
                      label: 'Pr\u00f3xima p\u00e1gina',
                      icon: Icons.chevron_right_rounded,
                      onPressed: compactOnNext,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

final class _CompactPageAction extends StatelessWidget {
  const _CompactPageAction({required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.square(CoeloSize.touchMin)),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.disabled)
                  ? colors.onSurfaceVariant
                  : colors.primary;
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused) ||
                  states.contains(WidgetState.pressed)) {
                return colors.primaryContainer;
              }
              return Colors.transparent;
            }),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ),
      ),
    );
  }
}
