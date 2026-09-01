import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Canonical private frame for Superadmin entity forms.
final class SuperadminFormFrame extends StatelessWidget {
  const SuperadminFormFrame({
    required this.navigation,
    required this.body,
    required this.footer,
    required this.viewportWidth,
    this.bodyMaxWidth = 880,
    this.scrollKey,
    super.key,
  });

  final Widget navigation;
  final Widget body;
  final Widget footer;
  final double viewportWidth;
  final double bodyMaxWidth;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final localWidth = constraints.maxWidth;
        final showRail = localWidth >= CoeloBreakpoints.medium.minWidth;
        final inset = showRail && localWidth >= CoeloBreakpoints.expanded.minWidth
            ? CoeloSpacing.space10
            : showRail
            ? CoeloSpacing.space6
            : CoeloSpacing.space4;
        final mainRegion = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: scrollKey,
                  padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!showRail) ...[navigation, const SizedBox(height: CoeloSpacing.space4)],
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: bodyMaxWidth),
                          child: body,
                        ),
                      ),
                      if (!showRail) ...[const SizedBox(height: CoeloSpacing.space6), footer],
                    ],
                  ),
                ),
              ),
              if (showRail) footer,
            ],
          ),
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, inset, inset, CoeloSpacing.space4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showRail) ...[navigation, const SizedBox(width: CoeloSpacing.space6)],
              mainRegion,
            ],
          ),
        );
      },
    );
  }
}
