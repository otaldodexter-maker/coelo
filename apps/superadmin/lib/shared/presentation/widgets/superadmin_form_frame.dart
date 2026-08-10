import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Canonical private frame for Superadmin entity forms.
final class SuperadminFormFrame extends StatelessWidget {
  const SuperadminFormFrame({
    required this.navigation,
    required this.body,
    required this.footer,
    required this.viewportWidth,
    this.scrollKey,
    super.key,
  });

  final Widget navigation;
  final Widget body;
  final Widget footer;
  final double viewportWidth;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showRail = viewportWidth >= 768;
        final inset = showRail && viewportWidth >= CoeloBreakpoints.large.minWidth
            ? CoeloSpacing.space10
            : showRail
            ? CoeloSpacing.space6
            : CoeloSpacing.space4;
        final mainRegion = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!showRail) ...[navigation, const SizedBox(height: CoeloSpacing.space4)],
              Expanded(
                child: SingleChildScrollView(
                  key: scrollKey,
                  padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 880),
                      child: body,
                    ),
                  ),
                ),
              ),
              footer,
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
