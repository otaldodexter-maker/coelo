import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  void _toggle() => setState(() => _expandedByTap = !_expandedByTap);

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: _buildStatus);

  Widget _buildStatus(BuildContext context, BoxConstraints constraints) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: widget.foregroundColor,
      fontWeight: MediaQuery.boldTextOf(context) ? FontWeight.bold : FontWeight.w600,
    );
    final painter =
        TextPainter(
          text: TextSpan(text: widget.label, style: labelStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(
          maxWidth: math.max(
            1.0,
            constraints.maxWidth - CoeloSpacing.space2 * 2 - CoeloSpacing.space1,
          ),
        );
    final expandedWidth = math.min(
      constraints.maxWidth,
      math.max(
        math.max(56.0, 24 + widget.label.length * 6.5),
        painter.width + CoeloSpacing.space2 * 2 + CoeloSpacing.space1,
      ),
    );
    final expandedHeight = math.max(CoeloSpacing.space6, painter.height + CoeloSpacing.space2);
    painter.dispose();
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: FocusableActionDetector(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _toggle();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: Semantics(
          button: true,
          label: widget.semanticLabel ?? 'Status: ${widget.label}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _expanded ? 1 : 0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? CoeloMotion.instant
                  : CoeloMotion.standard,
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: CoeloSize.touchMin,
                  minHeight: CoeloSize.touchMin,
                ),
                child: Align(
                  widthFactor: 1,
                  heightFactor: 1,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    key: widget.surfaceKey,
                    width: 24 + (expandedWidth - 24) * progress,
                    height: CoeloSpacing.space6 + (expandedHeight - CoeloSpacing.space6) * progress,
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
                              overflow: TextOverflow.clip,
                              style: labelStyle,
                            ),
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
