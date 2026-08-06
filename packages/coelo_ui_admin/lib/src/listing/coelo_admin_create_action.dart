import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

enum CoeloAdminCreateActionVariant { tile, banner }

final class CoeloAdminCreateAction extends StatelessWidget {
  const CoeloAdminCreateAction({
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
    this.variant = CoeloAdminCreateActionVariant.tile,
    this.description,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final CoeloAdminCreateActionVariant variant;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return _CoeloAdminCreateActionContent(
      label: label,
      onPressed: onPressed,
      icon: icon,
      variant: variant,
      description: description,
    );
  }
}

class _CoeloAdminCreateActionContent extends StatefulWidget {
  const _CoeloAdminCreateActionContent({
    required this.label,
    required this.onPressed,
    required this.icon,
    required this.variant,
    required this.description,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final CoeloAdminCreateActionVariant variant;
  final String? description;

  @override
  State<_CoeloAdminCreateActionContent> createState() => _CoeloAdminCreateActionContentState();
}

class _CoeloAdminCreateActionContentState extends State<_CoeloAdminCreateActionContent> {
  final FocusNode _focusNode = FocusNode();
  bool _hovered = false;
  bool _focused = false;

  bool get _highlighted => widget.onPressed != null && (_hovered || _focused);

  void _activate() {
    _focusNode.requestFocus();
    widget.onPressed?.call();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? CoeloMotion.instant
        : CoeloMotion.standard;

    final action = Semantics(
      label: widget.variant == CoeloAdminCreateActionVariant.banner && widget.description != null
          ? '${widget.label}. ${widget.description}'
          : widget.label,
      button: true,
      enabled: widget.onPressed != null,
      onTap: widget.onPressed == null ? null : _activate,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _highlighted ? 1 : 0),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) => Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            boxShadow: progress == 0
                ? const []
                : [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.15 * progress),
                      blurRadius: CoeloSpacing.space3 * progress,
                      spreadRadius: CoeloSpacing.spaceHalf * progress,
                      offset: Offset(0, CoeloSpacing.space1 * progress),
                    ),
                  ],
          ),
          child: CustomPaint(
            foregroundPainter: _DashedBorderPainter(
              color: Color.lerp(colors.outlineVariant, colors.primary, progress)!,
            ),
            child: Material(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              child: InkWell(
                focusNode: _focusNode,
                onTap: widget.onPressed == null ? null : _activate,
                onHover: (value) => setState(() => _hovered = value),
                onFocusChange: (value) => setState(() => _focused = value),
                borderRadius: BorderRadius.circular(CoeloRadius.lg),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                child: Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space4),
                  child: widget.variant == CoeloAdminCreateActionVariant.tile
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _CreateActionIcon(icon: widget.icon, progress: progress),
                              SizedBox(
                                height: MediaQuery.textScalerOf(context).scale(1) >= 1.75
                                    ? CoeloSpacing.space2
                                    : CoeloSpacing.space3,
                              ),
                              Text(widget.label),
                            ],
                          ),
                        )
                      : Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _CreateActionIcon(
                                icon: widget.icon,
                                progress: progress,
                                compact: true,
                              ),
                              const SizedBox(width: CoeloSpacing.space3),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(widget.label),
                                    if (widget.description case final description?)
                                      Text(description),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return widget.variant == CoeloAdminCreateActionVariant.banner
        ? ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CoeloSpacing.space20),
            child: action,
          )
        : action;
  }
}

class _CreateActionIcon extends StatelessWidget {
  const _CreateActionIcon({required this.icon, required this.progress, this.compact = false});

  final IconData icon;
  final double progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: compact ? CoeloSize.avatarMd : 56,
      height: compact ? CoeloSize.avatarMd : 56,
      decoration: BoxDecoration(
        color: Color.lerp(colors.surface, colors.primary, progress),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color.lerp(
              colors.shadow.withValues(alpha: 0.08),
              colors.primary.withValues(alpha: 0.15),
              progress,
            )!,
            blurRadius: CoeloSpacing.space2 + CoeloSpacing.space1 * progress,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Color.lerp(colors.primary, colors.onPrimary, progress),
        size: compact ? CoeloSize.iconSm : CoeloSize.iconMd,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(CoeloRadius.lg)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + CoeloSpacing.space2, metric.length)),
          paint,
        );
        distance += CoeloSpacing.space3;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}
