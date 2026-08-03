import 'dart:ui';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Private, measured glass footer shared by Superadmin forms.
final class SuperadminFormActionFooter extends StatefulWidget {
  const SuperadminFormActionFooter({
    required this.tertiaryAction,
    required this.continuationActions,
    this.onHeightChanged,
    this.surfaceKey,
    super.key,
  }) : assert(continuationActions.length > 0);

  final Widget tertiaryAction;
  final List<Widget> continuationActions;
  final ValueChanged<double>? onHeightChanged;
  final Key? surfaceKey;

  @override
  State<SuperadminFormActionFooter> createState() => _SuperadminFormActionFooterState();
}

final class _SuperadminFormActionFooterState extends State<SuperadminFormActionFooter> {
  final _measureKey = GlobalKey();
  double _lastHeight = 0;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      key: _measureKey,
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: CoeloSpacing.space3, sigmaY: CoeloSpacing.space3),
        child: Container(
          key: widget.surfaceKey,
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          decoration: BoxDecoration(
            color: colors.surface.withValues(
              alpha: Theme.brightnessOf(context) == Brightness.light ? 0.84 : 0.88,
            ),
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth) {
                  final compactActions = [
                    ...widget.continuationActions.reversed,
                    widget.tertiaryAction,
                  ];
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < compactActions.length; index++) ...[
                        SizedBox(width: double.infinity, child: compactActions[index]),
                        if (index < compactActions.length - 1)
                          const SizedBox(height: CoeloSpacing.space2),
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    widget.tertiaryAction,
                    const Spacer(),
                    for (var index = 0; index < widget.continuationActions.length; index++) ...[
                      if (index > 0) const SizedBox(width: CoeloSpacing.space2),
                      widget.continuationActions[index],
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _reportHeight() {
    if (!mounted || widget.onHeightChanged == null) return;
    final renderObject = _measureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final height = renderObject.size.height;
    if ((height - _lastHeight).abs() < 0.5) return;
    _lastHeight = height;
    widget.onHeightChanged!(height);
  }
}
