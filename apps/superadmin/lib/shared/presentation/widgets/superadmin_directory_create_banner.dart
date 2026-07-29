import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

Duration _interactionDuration(BuildContext context, Duration duration) {
  return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

final class SuperadminDirectoryCreateBanner extends StatelessWidget {
  const SuperadminDirectoryCreateBanner({
    required this.label,
    required this.description,
    required this.onPressed,
    required this.bannerKey,
    required this.surfaceKey,
    super.key,
  });

  final String label;
  final String description;
  final VoidCallback onPressed;
  final Key bannerKey;
  final Key surfaceKey;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: bannerKey,
      constraints: const BoxConstraints(minHeight: CoeloSpacing.space20),
      child: _DashedAction(
        surfaceKey: surfaceKey,
        onPressed: onPressed,
        builder: (highlighted) => Row(
          key: const Key('superadmin-directory-create-banner-content'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CreateIcon(highlighted: highlighted),
            const SizedBox(width: CoeloSpacing.space3),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(label), Text(description)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateIcon extends StatelessWidget {
  const _CreateIcon({required this.highlighted});

  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: highlighted ? 1 : 0),
      duration: _interactionDuration(context, CoeloMotion.standard),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Container(
        width: CoeloSize.avatarMd,
        height: CoeloSize.avatarMd,
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
              blurRadius: 8 + 4 * progress,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          Icons.add,
          color: Color.lerp(colors.primary, colors.onPrimary, progress),
          size: CoeloSize.iconSm,
        ),
      ),
    );
  }
}

class _DashedAction extends StatefulWidget {
  const _DashedAction({required this.onPressed, required this.builder, required this.surfaceKey});

  final VoidCallback onPressed;
  final Widget Function(bool highlighted) builder;
  final Key surfaceKey;

  @override
  State<_DashedAction> createState() => _DashedActionState();
}

class _DashedActionState extends State<_DashedAction> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _highlighted = true),
      onExit: (_) => setState(() => _highlighted = false),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _highlighted = value),
        child: TweenAnimationBuilder<double>(
          key: widget.surfaceKey,
          tween: Tween(begin: 0, end: _highlighted ? 1 : 0),
          duration: _interactionDuration(context, CoeloMotion.standard),
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
                        blurRadius: 12 * progress,
                        spreadRadius: 2 * progress,
                        offset: Offset(0, 4 * progress),
                      ),
                    ],
            ),
            child: CustomPaint(
              foregroundPainter: _DashedBorderPainter(
                color: Color.lerp(colors.outlineVariant, colors.primary, progress)!,
              ),
              child: Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(CoeloRadius.lg),
                child: InkWell(
                  onTap: widget.onPressed,
                  borderRadius: BorderRadius.circular(CoeloRadius.lg),
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                  child: Padding(
                    padding: const EdgeInsets.all(CoeloSpacing.space4),
                    child: Center(child: widget.builder(_highlighted)),
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
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
