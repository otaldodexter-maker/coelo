import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Compact semantic status used by administrative directory cards.
///
/// The Institutions directory is the visual baseline: rest is a 24 px dot;
/// hover, keyboard focus or touch expands the pill and reveals its text.
final class CoeloAdminExpandableStatusIndicator extends StatefulWidget {
  const CoeloAdminExpandableStatusIndicator({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.semanticLabel,
    this.surfaceKey,
    super.key,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final String? semanticLabel;
  final Key? surfaceKey;

  @override
  State<CoeloAdminExpandableStatusIndicator> createState() =>
      _CoeloAdminExpandableStatusIndicatorState();
}

final class _CoeloAdminExpandableStatusIndicatorState
    extends State<CoeloAdminExpandableStatusIndicator> {
  bool _hovered = false;
  bool _focused = false;
  bool _expandedByTap = false;

  bool get _expanded => _hovered || _focused || _expandedByTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: Semantics(
          button: true,
          label: widget.semanticLabel ?? 'Status: ${widget.label}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expandedByTap = !_expandedByTap),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _expanded ? 1 : 0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? CoeloMotion.instant
                  : CoeloMotion.standard,
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => Container(
                key: widget.surfaceKey,
                width: 24 + (math.max(56, 24 + widget.label.length * 6.5) - 24) * progress,
                height: CoeloSpacing.space6,
                padding: EdgeInsets.symmetric(horizontal: CoeloSpacing.space2 * progress),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(CoeloRadius.full),
                  border: Border.all(
                    color: widget.foregroundColor.withValues(alpha: _focused ? 0.48 : 0.28),
                    width: _focused ? 2 : 1,
                  ),
                ),
                child: progress == 0
                    ? null
                    : Opacity(
                        opacity: progress,
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: widget.foregroundColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
